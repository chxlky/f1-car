<script lang="ts">
    import { page } from "$app/state";
    import { onMount, onDestroy } from "svelte";
    import type { F1Car } from "$lib/bindings";
    import Joystick from "$lib/components/Joystick.svelte";
    import { commands } from "$lib/bindings";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import { goto } from "$app/navigation";
    import type { Orientation } from "$lib/bindings";

    let { carNumber } = page.params;

    let car = $state<F1Car | null>(null);
    let connectionStatus = $state<"disconnected" | "connecting" | "connected">("disconnected");

    onMount(async () => {
        // try to find car from cache
        car =
            f1DiscoveryService.carsArray.find((c) => String(c.number) === String(carNumber)) ??
            null;
        if (!car) {
            // fallback: refresh and try again
            await f1DiscoveryService.refreshCars();
            car =
                f1DiscoveryService.carsArray.find((c) => String(c.number) === String(carNumber)) ??
                null;
        }
        // select this car in the shared service so state is synced
        if (car) {
            f1DiscoveryService.selectCar(car.id);
        }
    });

    // Set orientation to landscape when entering the control page, and revert to portrait on exit
    onMount(async () => {
        try {
            const res = await commands.setOrientation("Landscape" as Orientation);
            if (res.status === "error") {
                console.error("Failed to set orientation to Landscape:", res.error);
            }
        } catch (err) {
            console.error("Error setting orientation to Landscape:", err);
        }
    });

    onDestroy(async () => {
        try {
            // revert orientation
            const res = await commands.setOrientation("Portrait" as Orientation);
            if (res.status === "error") {
                console.error("Failed to set orientation to Portrait:", res.error);
            }
        } catch (err) {
            console.error("Error setting orientation to Portrait:", err);
        }

        // ensure we disconnect and reset local state
        try {
            if (car) {
                await commands.disconnectCar(car.id);
            }
        } catch (err) {
            console.error("Error disconnecting on destroy:", err);
        }

        connectionStatus = "disconnected";
    });

    async function connect() {
        if (!car) return;
        // set shared state
        f1DiscoveryService.selectedConnection = "connecting";
        const res = await commands.connectToCar(car.id);
        if (res.status === "error") {
            console.error("Failed to connect:", res.error);
            connectionStatus = "disconnected";
            return;
        }

        // Let backend event or polling update the cache; reflect it here
        const updated = await f1DiscoveryService.getCarById(car.id);
        if (updated)
            f1DiscoveryService.selectedConnection =
                (updated.connection_status as any) === "Connected" ? "connected" : "connecting";
    }

    async function disconnect() {
        if (!car) return;
        await commands.disconnectCar(car.id);
        f1DiscoveryService.selectCar(null);
        goto("/#/");
    }

    async function goBack() {
        try {
            // revert orientation immediately for a snappier test
            await commands.setOrientation("Portrait");
        } catch (err) {
            console.error("Failed to set orientation to Portrait on back:", err);
        }
        goto("/#/");
    }

    function handleLeft(e: CustomEvent) {
        const { x, y } = e.detail;
        console.log("left joystick", x, y);
    }

    function handleRight(e: CustomEvent) {
        const { x, y } = e.detail;
        console.log("right joystick", x, y);
    }
</script>

<main class="p-6">
    <h1 class="text-2xl font-bold">Control car #{carNumber}</h1>
    {#if car}
        <p class="text-sm text-gray-400">Driver: {car.driver} — Team: {car.team}</p>
    {/if}

    <div class="mt-4 flex items-center gap-3">
        <div
            class="rounded-full px-3 py-1 text-sm font-medium"
            class:!bg-red-600={connectionStatus === "disconnected"}
            class:!bg-yellow-500={connectionStatus === "connecting"}
            class:!bg-green-600={connectionStatus === "connected"}
            style="color: white;">
            {connectionStatus}
        </div>

        {#if connectionStatus === "disconnected"}
            <button class="rounded bg-blue-600 px-3 py-1 text-white" onclick={connect}>
                Connect
            </button>
        {:else}
            <button class="rounded bg-gray-700 px-3 py-1 text-white" onclick={disconnect}>
                Disconnect
            </button>
        {/if}

        <button
            class="rounded border border-white/20 bg-transparent px-3 py-1 text-white"
            onclick={goBack}>
            ← Back
        </button>
    </div>

    <div class="mt-6 grid grid-cols-2 gap-4">
        <div class="flex flex-col items-center">
            <div class="mb-2 text-sm font-medium">Drive (Throttle / Steering)</div>
            <Joystick
                size={220}
                on:input={handleLeft}
                on:end={() => {
                    /* stop */
                }} />
        </div>

        <div class="flex flex-col items-center">
            <div class="mb-2 text-sm font-medium">Camera / Fine control</div>
            <Joystick
                size={180}
                on:input={handleRight}
                on:end={() => {
                    /* stop */
                }} />
        </div>
    </div>
</main>
