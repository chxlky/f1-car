<script lang="ts">
    import Header from "$lib/components/Header.svelte";
    import "../app.css";

    let { children } = $props();
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

	<Header />

	<!-- Content -->
	<div class="relative z-10">
		{@render children()}
	</div>
</div>
