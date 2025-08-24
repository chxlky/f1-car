<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { onMount } from "svelte";

    const dispatch = createEventDispatcher();

    export let size = 140; // px outer diameter
    export let knobSize = 56; // px knob diameter
    export let deadzone = 0.04; // radius fraction below which input is considered zero (0..1)
    export let clamp = 1.0; // allow clamping to 1.0

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

    function toNorm(pxX: number, pxY: number) {
        if (!rect) return { nx: 0, ny: 0 };
        const radius = (size - knobSize) / 2;
        // compute relative to center
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = pxX - cx;
        const dy = pyToCanvasY(pxY - cy); // invert Y so up is negative (forward)
        // clamp to radius
        const dist = Math.hypot(dx, dy);
        const r = Math.min(dist, radius);
        const nx = (dx / radius) * clamp;
        const ny = (dy / radius) * clamp;
        return { nx: nx, ny: ny, r, radius } as any;
    }

    // convert pointer Y to UI Y where upward movement is negative (vehicle forward)
    function pyToCanvasY(v: number) {
        return -v;
    }

    function applyNormalized(nx: number, ny: number) {
        // apply deadzone
        const mag = Math.hypot(nx, ny);
        if (mag < deadzone) {
            nx = 0;
            ny = 0;
        }

        // clamp magnitude to 1
        const m = Math.min(1, Math.hypot(nx, ny));
        if (m > 0) {
            nx = (nx / m) * Math.min(1, Math.hypot(nx, ny));
            ny = (ny / m) * Math.min(1, Math.hypot(nx, ny));
        }

        x = Number(nx.toFixed(3));
        y = Number(ny.toFixed(3));

        // update knob px positions for rendering
        const radiusPx = (size - knobSize) / 2;
        knobX = x * radiusPx;
        knobY = -y * radiusPx; // invert back for display (CSS top/left)
    }

    function pointerDown(e: PointerEvent) {
        (e.target as Element).setPointerCapture(e.pointerId);
        dragging = true;
        handlePointer(e.clientX, e.clientY);
    }

    function pointerMove(e: PointerEvent) {
        if (!dragging) return;
        handlePointer(e.clientX, e.clientY);
    }

    function pointerUp(e: PointerEvent) {
        try {
            (e.target as Element).releasePointerCapture(e.pointerId);
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
        // clamp
        const dist = Math.hypot(dx, dy);
        const clamped = dist > radius ? radius / dist : 1.0;
        const nx = (dx * clamped) / radius;
        const ny = (dy * clamped) / radius;
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
        class="relative flex items-center justify-center rounded-full border border-white/6 bg-white/4 backdrop-blur"
        style="width: {size}px; height: {size}px;">
        <div
            class="absolute flex items-center justify-center rounded-full border border-white/12 bg-white/8 shadow-[0_6px_14px_rgba(0,0,0,0.6),inset_0_-4px_8px_rgba(255,255,255,0.02)]"
            style="width: {knobSize}px; height: {knobSize}px; left: calc(50% + {knobX}px); top: calc(50% + {knobY}px); transform: translate(-50%, -50%);">
            <!-- visual center dot -->
            <div class="h-2 w-2 rounded-full bg-white/20"></div>
        </div>
    </div>
</div>
