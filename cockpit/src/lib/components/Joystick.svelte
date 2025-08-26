<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { onMount } from "svelte";

    // TODO: Update to svelte 5

    const dispatch = createEventDispatcher();

    export let size = 140; // px outer diameter
    export let knobSize = 56; // px knob diameter
    // minimal client-side joystick. Heavy math (deadzone/filter/mixing) is done in Rust.

    let root: HTMLDivElement | null = null;
    let rect: DOMRect | null = null;
    let dragging = false;
    let knobX = 0; // in px relative to center
    let knobY = 0;

    // normalized values -1..1 (x => left(-1) right(+1), y => forward(-1) back(+1))
    export let x = 0;
    export let y = 0;

    function updateRect() {
        if (root) rect = root.getBoundingClientRect();
    }

    onMount(() => {
        updateRect();
        const ro = new ResizeObserver(updateRect);
        if (root) ro.observe(root);
        return () => ro.disconnect();
    });

    // Note: we intentionally keep client-side math minimal. The Rust backend
    // performs deadzone, filtering and control mixing. toNorm is removed.

    // convert pointer Y to UI Y where upward movement is negative (vehicle forward)
    function pyToCanvasY(v: number) {
        return -v;
    }

    // Minimal mapping: set normalized -1..1 values and update knob position.
    function applyNormalized(nx: number, ny: number) {
        // No deadzone/filter here; backend will handle heavy processing.
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
        // capture on the element that the listener is bound to (currentTarget)
        // using e.target can pick an inner child and cause incorrect capture behavior
        // which in practice made center-press jump to the top.
        updateRect();
        try {
            (e.currentTarget as Element).setPointerCapture(e.pointerId);
        } catch {}
        dragging = true;
        dispatch("start");
        handlePointer(e.clientX, e.clientY);
    }

    function pointerMove(e: PointerEvent) {
        if (!dragging) return;
        handlePointer(e.clientX, e.clientY);
    }

    function pointerUp(e: PointerEvent) {
        try {
            (e.currentTarget as Element).releasePointerCapture(e.pointerId);
        } catch {}
        dragging = false;
        // return to center smoothly
        knobX = 0;
        knobY = 0;
        x = 0;
        y = 0;
        dispatch("input", { x, y });
        dispatch("end");
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
        dispatch("input", { x, y });
    }
</script>

<div
    bind:this={root}
    class="touch-none select-none"
    style="width: {size}px; height: {size}px;"
    on:pointerdown|preventDefault={pointerDown}
    on:pointermove|preventDefault={pointerMove}
    on:pointerup|preventDefault={pointerUp}
    on:pointercancel|preventDefault={pointerUp}>
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
