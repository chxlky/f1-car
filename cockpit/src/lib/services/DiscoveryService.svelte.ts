import type { UnlistenFn } from "@tauri-apps/api/event";
import { SvelteMap as Map } from "svelte/reactivity";
import {
    commands,
    events,
    type ConnectionStatus,
    type DiscoveryStatusEvent,
    type F1Car
} from "../bindings";

// TODO: when the car is turned off, and refresh is called, the old car still persists
// we need to clear any cars when refresh is called.

export class F1CarDiscoveryService {
    cars = $state(new Map<string, F1Car>());
    selectedCarId = $state<string | undefined>(undefined);
    selectedConnection = $state<ConnectionStatus>("Disconnected");
    isRunning = $state(false);
    error = $state<string | undefined>(undefined);
    private unlistenFns: UnlistenFn[] = [];
    private statusListeners: Array<(status: DiscoveryStatusEvent) => void> = [];
    private carListeners: Array<(cars: F1Car[], count: number) => void> = [];

    selectCar(carId: string | undefined) {
        this.selectedCarId = carId;
        if (!carId) {
            this.selectedConnection = "Disconnected";
        } else {
            const car = this.cars.get(carId);
            this.selectedConnection = car?.connectionStatus ?? "Disconnected";
        }
    }

    async startDiscovery(): Promise<void> {
        console.log("Starting mDNS discovery...");

        try {
            this.error = undefined;

            await this.setupEventListeners();
            await commands.startDiscovery().then((res) => {
                if (res.status === "error") {
                    throw new Error(`Failed to start discovery: ${res.error}`);
                }
            });

            this.isRunning = true;
            await this.refreshCars();
        } catch (error) {
            this.error = `Failed to start discovery: ${error}`;
            this.isRunning = false;

            throw new Error(this.error);
        }
    }

    async stopDiscovery(): Promise<void> {
        console.log("Stopping mDNS discovery...");

        try {
            this.error = undefined;
            await commands.stopDiscovery().then((res) => {
                if (res.status === "error") {
                    console.error(`Failed to stop discovery: ${res.error.message}`);
                }
            });

            this.isRunning = false;

            await this.cleanupEventListeners();
        } catch (err) {
            this.error = `Failed to stop discovery: ${err}`;
            console.error(this.error);
        }
    }

    async refreshCars(): Promise<F1Car[]> {
        try {
            this.error = undefined;

            // Clear existing cars before refreshing to remove stale entries
            this.cars.clear();

            await commands.getDiscoveredCars().then((res) => {
                if (res.status === "error") {
                    throw new Error(`Failed to refresh cars: ${res.error.message}`);
                }

                // Add only the currently discovered cars
                res.data.forEach((car) => this.cars.set(car.id, car));

                // notify listeners with the derived array and count
                this.notifyCarListeners();
            });

            return Array.from(this.cars.values());
        } catch (err) {
            this.error = `Failed to refresh cars: ${err}`;
            console.error(this.error);

            return [];
        }
    }

    async getCarById(carId: string): Promise<F1Car | null> {
        const cached = this.cars.get(carId);
        if (cached) return cached;

        return commands
            .getCarById(carId)
            .then((res) => {
                if (res.status === "error") {
                    console.error(`Failed to get car: ${res.error?.message ?? res.error}`);
                    return null;
                }

                if (res.data) {
                    this.cars.set(res.data.id, res.data);
                    // notify callers that our backing map changed
                    this.notifyCarListeners();
                    return res.data;
                }
                return null;
            })
            .catch((err) => {
                console.error(`Error getting car by ID: ${err}`);
                return null;
            });
    }

    async checkIsRunning(): Promise<boolean> {
        return commands
            .isDiscoveryRunning()
            .then((res) => {
                if (res.status === "error") {
                    console.error(`Failed to check running status: ${res.error}`);
                    this.isRunning = false;
                    return false;
                }

                this.isRunning = !!res.data;
                return this.isRunning;
            })
            .catch((err) => {
                console.error(`Error checking discovery status: ${err}`);
                this.isRunning = false;
                return false;
            });
    }

    getCarByNumber(number: number): F1Car | undefined {
        return Array.from(this.cars.values()).find((car) => car.number === number);
    }

    onStatusChanged(callback: (status: DiscoveryStatusEvent) => void): () => void {
        this.statusListeners.push(callback);

        return () => {
            const index = this.statusListeners.indexOf(callback);
            if (index > -1) {
                this.statusListeners.splice(index, 1);
            }
        };
    }

    onCarsChanged(callback: (cars: F1Car[], count: number) => void): () => void {
        this.carListeners.push(callback);

        return () => {
            const idx = this.carListeners.indexOf(callback);
            if (idx > -1) this.carListeners.splice(idx, 1);
        };
    }

    private notifyCarListeners(): void {
        const arr = Array.from(this.cars.values()).sort((a, b) => a.number - b.number);
        const count = arr.length;
        // update any derived state if needed (not storing derived state anymore)
        this.carListeners.forEach((cb) => cb(arr, count));
    }

    clearError(): void {
        this.error = undefined;
    }

    private async setupEventListeners(): Promise<void> {
        const unlistenDiscovered = await events.carDiscoveredEvent.listen((event) => {
            const data = event.payload;
            this.cars.set(data.car.id, data.car);
            // if this is the selected car, update connection state
            if (this.selectedCarId === data.car.id) {
                this.selectedConnection = data.car.connectionStatus;
            }
            // notify listeners with the updated derived list/count
            this.notifyCarListeners();
            console.log(
                `mDNS: Car discovered: #${data.car.number} ${data.car.driver} (${data.car.team}) id=${data.car.id} ip=${data.car.ip}`
            );
        });

        const unlistenUpdated = await events.carUpdatedEvent.listen((event) => {
            const data = event.payload;
            this.cars.set(data.car.id, data.car);
            if (this.selectedCarId === data.car.id) {
                this.selectedConnection = data.car.connectionStatus;
            }
            this.notifyCarListeners();
            console.log(`mDNS: Car updated: id=${data.car.id} #${data.car.number}`);
        });

        const unlistenOffline = await events.carOfflineEvent.listen((event) => {
            const data = event.payload;
            if (this.cars.has(data.car.id)) {
                this.cars.set(data.car.id, data.car);
                if (this.selectedCarId === data.car.id) {
                    this.selectedConnection = data.car.connectionStatus;
                }
                this.notifyCarListeners();
                console.log(`mDNS: Car offline: id=${data.car.id} #${data.car.number}`);
            }
        });

        const unlistenRemoved = await events.carRemovedEvent.listen((event) => {
            const data = event.payload;
            this.cars.delete(data.carId);
            // clear selection if the removed car was selected
            if (this.selectedCarId === data.carId) {
                this.selectCar(undefined);
            }
            this.notifyCarListeners();
            console.log(`mDNS: Car removed: ${data.carId}`);
        });

        const unlistenStatus = await events.discoveryStatusEvent.listen((event) => {
            const data = event.payload;
            console.log(`Discovery status: ${data.message} (running: ${data.isRunning})`);
            this.isRunning = data.isRunning;
            this.notifyStatusListeners(data);
        });

        this.unlistenFns = [
            unlistenDiscovered,
            unlistenUpdated,
            unlistenOffline,
            unlistenRemoved,
            unlistenStatus
        ];
    }

    private async cleanupEventListeners(): Promise<void> {
        for (const unlisten of this.unlistenFns) {
            unlisten();
        }
        this.unlistenFns = [];
    }

    private notifyStatusListeners(status: DiscoveryStatusEvent): void {
        this.statusListeners.forEach((callback) => callback(status));
    }
}

export const f1DiscoveryService = new F1CarDiscoveryService();
