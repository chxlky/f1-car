<script lang="ts">
    interface Props {
        streamUrl: string;
    }

    let { streamUrl }: Props = $props();
</script>

<img
    src={streamUrl}
    alt="MJPEG Stream"
    class="h-54 w-96 rounded border border-white/20"
/>
