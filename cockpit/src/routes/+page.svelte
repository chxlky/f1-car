<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { goto } from "$app/navigation";
    import type { F1Car } from "$lib/bindings";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import CarCard from "$lib/components/CarCard.svelte";
    import Header from "$lib/components/Header.svelte";
    import { commands, events } from "$lib/bindings";

    // use shared selection/connection state from discovery service
    let selectedCar: F1Car | null = null;
    $: selectedCar = f1DiscoveryService.selectedCarId
        ? (f1DiscoveryService.cars.get(f1DiscoveryService.selectedCarId) ?? null)
        : null;
    $: connectionStatus = f1DiscoveryService.selectedConnection;

    // local reactive copies for template binding
    let carsArray: F1Car[] = [];
    let carCount = 0;

    let unsubscribeStatus: (() => void) | null = null;
    let unsubscribeCars: (() => void) | null = null;

    onMount(async () => {
        try {
            await f1DiscoveryService.checkIsRunning();
            unsubscribeStatus = f1DiscoveryService.onStatusChanged((status) => {
                console.log("Status changed:", status);
            });

            // subscribe to car list updates
            unsubscribeCars = f1DiscoveryService.onCarsChanged((cars, count) => {
                carsArray = cars;
                carCount = count;
            });

            if (!f1DiscoveryService.isRunning) {
                await f1DiscoveryService.startDiscovery();
            } else {
                await f1DiscoveryService.refreshCars();
            }
        } catch (err) {
            console.error("Failed to initialize discovery:", err);
        }
    });

    onDestroy(async () => {
        if (unsubscribeStatus) {
            unsubscribeStatus();
        }
        if (unsubscribeCars) {
            unsubscribeCars();
        }
        /* if (wsConnection) {
			wsConnection.disconnect();
		} */
    });

    async function connectToCar(car: F1Car) {
        // set shared state
        f1DiscoveryService.selectCar(car.id);
        f1DiscoveryService.selectedConnection = "connecting";

        // Ask backend to connect; backend will emit updates we listen for
        const res = await commands.connectToCar(car.id);
        if (res.status === "error") {
            console.error("Failed to connect:", res.error);
            f1DiscoveryService.selectCar(null);
            return;
        }

        // navigate to control page for this car
        goto(`/#/control/${encodeURIComponent(String(car.number))}`);
    }

    async function disconnect() {
        /* if (wsConnection) {
			wsConnection.disconnect();
			wsConnection = null;
		} */
        if (f1DiscoveryService.selectedCarId) {
            await commands.disconnectCar(f1DiscoveryService.selectedCarId);
        }
        f1DiscoveryService.selectCar(null);
        console.log("Disconnected from car");
    }
</script>

<div class="text-white">
    <Header />
    <main class="mx-auto max-w-7xl p-6">
        {#if f1DiscoveryService.error}
            <div class="mb-6 rounded border border-red-500 bg-red-900/50 px-4 py-3 text-red-200">
                <strong>Error:</strong>
                {f1DiscoveryService.error}
                <button
                    onclick={f1DiscoveryService.clearError}
                    class="float-right text-red-300 hover:text-white">
                    ×
                </button>
            </div>
        {/if}

        <h1 class="mt-12 text-center font-f1 text-4xl">DISCOVER CARS</h1>

        <div class="mt-8">
            {#if carCount === 0}
                <div class="py-16 text-center text-gray-400">
                    <div class="mb-4 text-6xl">🏎️</div>
                    <h3 class="mb-2 text-xl font-bold">No F1 Cars Discovered</h3>
                    <p class="text-sm">
                        {f1DiscoveryService.isRunning
                            ? "Scanning for cars on the network..."
                            : "Start discovery to find F1 cars on your network"}
                    </p>
                </div>
            {:else}
                <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
                    {#each carsArray as car (car.id)}
                        <CarCard
                            {car}
                            onConnect={connectToCar}
                            isSelected={selectedCar?.id === car.id &&
                                connectionStatus === "connected"}
                            isConnecting={selectedCar?.id === car.id &&
                                connectionStatus === "connecting"} />
                    {/each}
                </div>
            {/if}
        </div>
    </main>
</div>
