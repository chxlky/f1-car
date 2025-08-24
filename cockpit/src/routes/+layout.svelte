<script lang="ts">
    import "../app.css";

    let { children } = $props();
</script>

<svelte:head>
    <link rel="icon" href="/favicon.svg" />
</svelte:head>

<div class="relative min-h-screen overflow-x-hidden bg-f1-dark">
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
