<script lang="ts">
    import { onDestroy, onMount } from "svelte";
    import { attachConsole } from "@tauri-apps/plugin-log";
    import type { UnlistenFn } from "@tauri-apps/api/event";
    import "../app.css";

    let { children } = $props();

    let detach = $state<UnlistenFn | undefined>();

    onMount(async () => {
        detach = await attachConsole();
    });

    onDestroy(() => detach?.());
</script>

<svelte:head>
    <link rel="icon" href="/favicon.svg" />
</svelte:head>

<div class="bg-f1-dark relative min-h-screen overflow-x-hidden">
    <!-- Background pattern -->
    <img
        src="/svg/f1-lines.svg"
        alt=""
        class="pointer-events-none fixed inset-0 z-20 h-screen w-screen object-cover opacity-10" />

    <!-- Content -->
    <div class="relative z-10">
        {@render children()}
    </div>
</div>
