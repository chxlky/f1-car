<script lang="ts">
    import { startCamera, stopCamera } from "$lib/services/camera";
    import { error, info } from "@tauri-apps/plugin-log";
    import { onDestroy, onMount } from "svelte";

    interface Props {
        ip: string;
    }

    let { ip }: Props = $props();

    let isStreaming = $state<boolean>(false);
    let streamUrl = $derived(`http://${ip}:8081/stream`);

    onMount(async () => {
        info(`Starting camera feed for ${ip}`);
        await startCamera(ip).then((res) => {
            console.log("hello, this is running");
            if (res.success) {
                isStreaming = true;
            } else {
                error(`Failed to start camera feed: ${JSON.stringify(res)}`);
            }
        });
    });

    onDestroy(async () => {
        info(`Stopping camera feed for ${ip}`);
        await stopCamera(ip).then((res) => {
            if (res.success) {
                isStreaming = false;
            } else {
                error(`Failed to stop camera feed: ${JSON.stringify(res)}`);
            }
        });
    });
</script>

{#if isStreaming}
    <img src={streamUrl} alt="MJPEG Stream" class="h-54 w-96 rounded border border-white/20" />
{/if}
