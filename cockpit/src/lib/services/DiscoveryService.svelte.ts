import type { UnlistenFn } from "@tauri-apps/api/event";
import { SvelteMap as Map } from "svelte/reactivity";
import {
    commands,
    events,
    type CarDiscoveredEvent,
    type CarOfflineEvent,
    type CarRemovedEvent,
    type CarUpdatedEvent,
    type DiscoveryStatusEvent,
    type F1Car
} from "../bindings";

export class F1CarDiscoveryService {
    cars = $state(new Map<string, F1Car>());
    isRunning = $state(false);
    discoveryStatus = $state<string>("Stopped");
    error = $state<string | null>(null);

    private unlistenFns: UnlistenFn[] = [];
    private statusListeners: Array<(status: DiscoveryStatusEvent) => void> = [];

    carsArray = $derived(Array.from(this.cars.values()).sort((a, b) => a.number - b.number));
    carCount = $derived(this.carsArray.length);

    async startDiscovery(): Promise<void> {
        console.log("Starting mDNS discovery...");

        try {
            this.error = null;
            this.discoveryStatus = "Starting...";

            await this.setupEventListeners();
            await commands.startDiscovery().then((res) => {
                if (res.status === "error") {
                    throw new Error(`Failed to start discovery: ${res.error}`);
                }
            });

            this.isRunning = true;

            // Refresh cars to get any that might have been discovered before we started
            await this.refreshCars();
            this.discoveryStatus = "Running";
        } catch (error) {
            this.error = `Failed to start discovery: ${error}`;
            this.isRunning = false;
            this.discoveryStatus = "Error";

            throw new Error(this.error);
        }
    }

    async stopDiscovery(): Promise<void> {
        console.log("Stopping mDNS discovery...");

        try {
            this.error = null;
            await commands.stopDiscovery().then((res) => {
                if (res.status === "error") {
                    console.error(`Failed to stop discovery: ${res.error.message}`);
                }
            });

            this.isRunning = false;
            this.discoveryStatus = "Stopped";

            // Cleanup event listeners
            await this.cleanupEventListeners();
        } catch (err) {
            this.error = `Failed to stop discovery: ${err}`;
            console.error(this.error);
        }
    }

    async refreshCars(): Promise<F1Car[]> {
        try {
            this.error = null;
            await commands.getDiscoveredCars().then((res) => {
                if (res.status === "error") {
                    throw new Error(`Failed to refresh cars: ${res.error.message}`);
                }

                this.cars.clear();
                res.data.forEach((car) => {
                    this.cars.set(car.id, car);
                });
            });

            return Array.from(this.cars.values());
        } catch (err) {
            this.error = `Failed to refresh cars: ${err}`;
            console.error(this.error);
            return [];
        }
    }

    async getCarById(carId: string): Promise<F1Car | null> {
        // Check local cache first
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
                    // cache and return the remote car
                    this.cars.set(res.data.id, res.data);
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
                    console.error(
                        `Failed to check running status: ${res.error?.message ?? res.error}`
                    );
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

    // Get car by various criteria
    getCarByNumber(number: number): F1Car | undefined {
        return this.carsArray.find((car) => car.number === number);
    }

    getCarsByTeam(team: string): F1Car[] {
        return this.carsArray.filter((car) => car.team.toLowerCase().includes(team.toLowerCase()));
    }

    getCarsByDriver(driver: string): F1Car[] {
        return this.carsArray.filter((car) =>
            car.driver.toLowerCase().includes(driver.toLowerCase())
        );
    }

    // Status change listener
    onStatusChanged(callback: (status: DiscoveryStatusEvent) => void): () => void {
        this.statusListeners.push(callback);

        return () => {
            const index = this.statusListeners.indexOf(callback);
            if (index > -1) {
                this.statusListeners.splice(index, 1);
            }
        };
    }

    clearError(): void {
        this.error = null;
    }

    // Private methods
    private async setupEventListeners(): Promise<void> {
        // Listen for car discovered events
        const unlistenDiscovered = await events.carDiscoveredEvent.listen((event) => {
            const data = event.payload as CarDiscoveredEvent;
            this.cars.set(data.car.id, data.car);
            console.log(
                `mDNS: Car discovered: #${data.car.number} ${data.car.driver} (${data.car.team}) id=${data.car.id} ip=${data.car.ip}`
            );
        });

        // Listen for car updated events
        const unlistenUpdated = await events.carUpdatedEvent.listen((event) => {
            const data = event.payload as CarUpdatedEvent;
            this.cars.set(data.car.id, data.car);
            console.log(`mDNS: Car updated: id=${data.car.id} #${data.car.number}`);
        });

        // Listen for car offline events
        const unlistenOffline = await events.carOfflineEvent.listen((event) => {
            const data = event.payload as CarOfflineEvent;
            if (this.cars.has(data.car.id)) {
                this.cars.set(data.car.id, data.car);
                console.log(`mDNS: Car offline: id=${data.car.id} #${data.car.number}`);
            }
        });

        // Listen for car removed events
        const unlistenRemoved = await events.carRemovedEvent.listen((event) => {
            const data = event.payload as CarRemovedEvent;
            this.cars.delete(data.car_id);
            console.log(`🗑️ mDNS: Car removed: ${data.car_id}`);
        });

        // Listen for discovery status events
        const unlistenStatus = await events.discoveryStatusEvent.listen((event) => {
            const data = event.payload as DiscoveryStatusEvent;
            console.log(`📡 Discovery status: ${data.message} (running: ${data.is_running})`);
            this.isRunning = data.is_running;
            this.discoveryStatus = data.message;
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
