<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { goto } from "$app/navigation";
    import { info, error } from "@tauri-apps/plugin-log";
    import { type F1Car, commands } from "$lib/bindings";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import CarCard from "$lib/components/CarCard.svelte";
    import Header from "$lib/components/Header.svelte";

    let selectedCarId = $derived(f1DiscoveryService.selectedCarId!);
    let selectedCar = $derived(
        selectedCarId ? f1DiscoveryService.cars.get(selectedCarId) : undefined
    );
    let connectionStatus = $derived(f1DiscoveryService.selectedConnection);

    let carsArray = $derived(
        Array.from(f1DiscoveryService.cars.values()).sort((a, b) => a.number - b.number)
    );
    let carCount = $derived(carsArray.length);

    let unsubscribeStatus: (() => void) | null = null;
    let unsubscribeCars: (() => void) | null = null;

    onMount(async () => {
        try {
            await f1DiscoveryService.checkIsRunning();
            unsubscribeStatus = f1DiscoveryService.onStatusChanged((status) => {
                info(`Status changed: ${status}`);
            });

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
            error(`Failed to initialize discovery: ${err}`);
        }
    });

    onDestroy(async () => {
        unsubscribeStatus?.();
        unsubscribeCars?.();
    });

    async function connectToCar(car: F1Car) {
        f1DiscoveryService.selectCar(car.id);
        f1DiscoveryService.selectedConnection = "Connecting";

        await commands.connectToCar(car.id).then((res) => {
            if (res.status === "error") {
                error(`Failed to connect: ${res.error}`);
                f1DiscoveryService.selectCar(undefined);
                return res;
            }
        });

        goto(`/#/control/${encodeURIComponent(String(car.number))}`);
    }
</script>

<div class="text-white">
    <Header />
    <div class="mx-auto max-w-7xl p-6">
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

        <h1 class="font-f1 mt-12 text-center text-4xl">DISCOVER CARS</h1>

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
                                connectionStatus === "Connected"}
                            isConnecting={selectedCar?.id === car.id &&
                                connectionStatus === "Connecting"} />
                    {/each}
                </div>
            {/if}
        </div>
    </div>
</div>
