<script lang="ts">
    import { onMount } from "svelte";
    import { ChevronUp, ChevronDown, ChevronLeft, ChevronRight } from "@lucide/svelte";

    interface Props {
        size: number;
        knobSize: number;
        x: number;
        y: number;
        label: "Throttle" | "Steering";
        start: () => void;
        input: (x: number, y: number) => void;
        end: () => void;
    }

    let { size = 140, knobSize = 56, x = 0, y = 0, label, start, input, end }: Props = $props();

    let root = $state<HTMLDivElement | null>(null);
    let rect = $state<DOMRect | null>(null);
    let dragging = $state(false);
    let knobX = $state(0); // in px relative to center
    let knobY = $state(0); // in px relative to center

    function updateRect() {
        if (root) rect = root.getBoundingClientRect();
    }

    onMount(() => {
        updateRect();
        const ro = new ResizeObserver(updateRect);
        if (root) ro.observe(root);
        return () => ro.disconnect();
    });

    // convert pointer Y to UI Y where upward movement is negative (vehicle forward)
    function pyToCanvasY(v: number) {
        return -v;
    }

    // Minimal mapping: set normalized -1..1 values and update knob position.
    function applyNormalized(nx: number, ny: number) {
        const nxClamped = Math.max(-1, Math.min(1, nx));
        const nyClamped = Math.max(-1, Math.min(1, ny));

        x = Number(nxClamped.toFixed(3));
        y = Number(nyClamped.toFixed(3));

        // update knob px positions for rendering (simple linear mapping)
        const radiusPx = (size - knobSize) / 2;
        knobX = x * radiusPx;
        knobY = -y * radiusPx; // invert back for display (CSS top/left)
    }

    function pointerDown(e: PointerEvent) {
        e.preventDefault();

        // capture on the element that the listener is bound to (currentTarget)
        // using e.target can pick an inner child and cause incorrect capture behavior
        // which in practice made center-press jump to the top.
        updateRect();
        try {
            (e.currentTarget as Element).setPointerCapture(e.pointerId);
        } catch {}
        dragging = true;

        start();
        handlePointer(e.clientX, e.clientY);
    }

    function pointerMove(e: PointerEvent) {
        e.preventDefault();
        if (!dragging) return;
        handlePointer(e.clientX, e.clientY);
    }

    function pointerUp(e: PointerEvent) {
        e.preventDefault();

        try {
            (e.currentTarget as Element).releasePointerCapture(e.pointerId);
        } catch {}
        dragging = false;
        // return to center smoothly
        knobX = 0;
        knobY = 0;
        x = 0;
        y = 0;
        input(x, y);

        end();
    }

    function handlePointer(px: number, py: number) {
        if (!rect) updateRect();
        if (!rect) return;
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = px - cx;
        const dy = pyToCanvasY(py - cy);
        const radius = (size - knobSize) / 2;
        // clamp to radius in pixels then normalize to -1..1 for sending to backend
        const dist = Math.hypot(dx, dy);
        const clamped = dist > radius ? radius / dist : 1.0;
        const nx = (dx * clamped) / radius;
        const ny = (dy * clamped) / radius;
        // apply minimal mapping and update UI; heavy math happens in Rust
        applyNormalized(nx, ny);
        input(x, y);
    }
</script>

<div
    bind:this={root}
    class="relative touch-none select-none"
    style="width: {size}px; height: {size}px;"
    onpointerdown={pointerDown}
    onpointermove={pointerMove}
    onpointerup={pointerUp}
    onpointercancel={pointerUp}>
    {#if label === "Throttle"}
        <div class="absolute left-1/2 top-2 -translate-x-1/2 transform text-white/40 z-50">
            <ChevronUp size={16} />
        </div>
        <div class="absolute bottom-2 left-1/2 -translate-x-1/2 transform text-white/40 z-50">
            <ChevronDown size={16} />
        </div>
    {:else if label === "Steering"}
        <div class="absolute left-2 top-1/2 -translate-y-1/2 transform text-white/40 z-50">
            <ChevronLeft size={16} />
        </div>
        <div class="absolute right-2 top-1/2 -translate-y-1/2 transform text-white/40 z-50">
            <ChevronRight size={16} />
        </div>
    {/if}

    <div
        class="border-white/6 bg-white/4 relative flex items-center justify-center rounded-full border backdrop-blur"
        style="width: {size}px; height: {size}px;">
        <div
            class="border-white/12 bg-white/8 absolute flex items-center justify-center rounded-full border shadow-[0_6px_14px_rgba(0,0,0,0.6),inset_0_-4px_8px_rgba(255,255,255,0.02)]"
            style="width: {knobSize}px; height: {knobSize}px; left: calc(50% + {knobX}px); top: calc(50% + {knobY}px); transform: translate(-50%, -50%);">
            <!-- visual center dot -->
            <div class="h-2 w-2 rounded-full bg-white/20"></div>
        </div>
    </div>
</div>
