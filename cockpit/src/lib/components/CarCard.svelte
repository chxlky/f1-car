<script lang="ts">
    import type { F1Car } from "$lib/bindings";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";

    interface Props {
        car: F1Car;
        onConnect: (car: F1Car) => void;
        isSelected: boolean;
        isConnecting: boolean;
    }

    let { car, onConnect, isSelected, isConnecting }: Props = $props();

    const [firstName, ...lastNameParts] = car.driver.split(" ");
    const lastName = lastNameParts.join(" ");

    let remoteCar = $derived(f1DiscoveryService.cars.get(car.id));
    let isConnectedRemote = $derived(remoteCar!.connection_status === "Connected");
</script>

<div
    class="flex h-full flex-col justify-between rounded-lg border border-white/20 bg-white/5 p-6 transition-all hover:border-white/50 hover:bg-white/10">
    <div class="flex items-start justify-between">
        <div class="ml-4 text-center">
            <p class="font-f1-cursive text-4xl italic leading-none text-white">{firstName}</p>
            <h3 class="font-f1 text-3xl uppercase text-white">{lastName}</h3>
            <!-- <p class="text-md mt-1 text-gray-300">{car.team}</p> -->
        </div>
        <div class="text-right">
            <span class="font-f1-block text-5xl text-white/80">#{car.number}</span>
            <!-- <img src="/car-numbers/${car.number}.png" alt="${car.number}" /> -->
        </div>
    </div>

    <button
        onclick={() => onConnect(car)}
        disabled={isConnecting}
        class="font-f1 mt-6 w-full rounded-md border border-white/50 bg-transparent px-4 py-2 text-white transition-colors hover:bg-white hover:text-black disabled:cursor-not-allowed disabled:border-gray-600 disabled:bg-gray-800 disabled:text-gray-500">
        {#if isSelected && isConnecting}
            Connecting...
        {:else if isConnectedRemote}
            Connected
        {:else}
            Connect
        {/if}
    </button>
</div>
