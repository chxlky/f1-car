<script>
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import { RefreshCcw } from "@lucide/svelte";
    import { vibrate } from "@tauri-apps/plugin-haptics";
</script>

<header class="mt-5 bg-f1-dark p-8">
    <div class="mx-auto flex max-w-7xl items-center justify-between">
        <div class="flex items-center gap-2">
            <img src="/svg/f175.svg" alt="F1 Logo" class="z-50 h-8 w-auto" />
        </div>
        <div class="flex items-center text-white">
            <button
                class="z-50 rounded-full p-2 transition-all hover:bg-gray-700 active:scale-95 active:bg-gray-500"
                onclick={async () => {
                    await vibrate(100);
                    console.log("Refresh clicked");
                    f1DiscoveryService.refreshCars();
                }}>
                <RefreshCcw />
            </button>
        </div>
    </div>
</header>
