<script lang="ts">
    import type { F1Car } from "$lib/bindings";

    let { selectedCar }: { selectedCar: F1Car } = $props();
</script>

<section class="bg-f1-gray border-f1-border mt-8 rounded-lg border p-6">
    <h3 class="mb-4 text-xl font-bold">
        CONNECTED TO #{selectedCar.number}
        {selectedCar.driver.toUpperCase()}
    </h3>

    <div class="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
        <div class="bg-f1-dark border-f1-border rounded border p-4">
            <p class="text-sm text-gray-400">Driver</p>
            <p class="text-lg font-bold">{selectedCar.driver}</p>
        </div>
        <div class="bg-f1-dark border-f1-border rounded border p-4">
            <p class="text-sm text-gray-400">Team</p>
            <p class="text-lg font-bold">{selectedCar.team}</p>
        </div>
        <div class="bg-f1-dark border-f1-border rounded border p-4">
            <p class="text-sm text-gray-400">Car Number</p>
            <p class="text-lg font-bold">#{selectedCar.number}</p>
        </div>
        <div class="bg-f1-dark border-f1-border rounded border p-4">
            <p class="text-sm text-gray-400">Connection</p>
            <p class="text-lg font-bold text-green-500">LIVE</p>
        </div>
    </div>

    <div class="text-center">
        <p class="text-sm text-gray-400">Ready to receive telemetry data and send controls</p>
    </div>
</section>
