<script lang="ts">
    import { page } from "$app/state";
    import { goto } from "$app/navigation";
    import { onMount, onDestroy } from "svelte";
    import { type ConnectionStatus, type F1Car, commands } from "$lib/bindings";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import { startJoystickWs, closeJoystickWs, sendJoystickSample } from "$lib/services/joystickWs";
    import { startCamera, stopCamera } from "$lib/services/camera";
    import { ChevronLeft } from "@lucide/svelte";
    import { vibrate } from "@tauri-apps/plugin-haptics";
    import { info, error } from "@tauri-apps/plugin-log";
    import Joystick from "$lib/components/Joystick.svelte";
    import VideoStream from "$lib/components/VideoStream.svelte";

    let { carNumber } = page.params;

    let car = $state<F1Car | null>(null);
    let connectionStatus = $state<ConnectionStatus>("Disconnected");

    let leftX = $state(0);
    let leftY = $state(0); // throttle

    let rightX = $state(0); // steering
    let rightY = $state(0);

    let holdIntervalId = $state<number | null>(null);
    const HOLD_SEND_HZ = 20; // send while held at 20Hz

    let isStreaming = $state<boolean>(false);

    onMount(async () => {
        await commands
            .setOrientation("Landscape")
            .then(async (res) => {
                if (res.status === "error") {
                    error(`Failed to set orientation to Landscape: ${res.error}`);
                }

                car = f1DiscoveryService.getCarByNumber(Number(carNumber)) ?? null;
                f1DiscoveryService.selectCar(car?.id);

                if (car?.ip) {
                    const radioAddr = `${car.ip}:8080`;
                    await commands
                        .startJoystickService(9001, radioAddr)
                        .then((res) => {
                            if (res.status === "error") {
                                error(`Failed to start joystick service: ${res.error}`);
                            } else {
                                info(`Joystick service started for ${radioAddr}`);
                            }

                            // open a local websocket to the Tauri joystick service so UI samples get forwarded
                            startJoystickWs();
                        })
                        .catch((e: unknown) => error(`Failed to start joystick service: ${e}`));
                }

                await connect().then(() => {
                    connectionStatus = "Connected";
                    info(`Connected to car ${car?.number}`);
                });
            })
            .catch(() => {
                error("Error setting orientation to Landscape");
            });

        // Start camera stream automatically
        if (car?.ip) {
            info(`Starting camera stream for ${car.ip}`);
            const result = await startCamera(car.ip);
            info(`startCamera result: ${JSON.stringify(result)}`);
            if (result.success) {
                isStreaming = true;
            } else {
                error(`Failed to start camera stream: ${JSON.stringify(result)}`);
            }
        }
    });

    onDestroy(async () => {
        await commands
            .setOrientation("Portrait")
            .then((res) => {
                if (res.status === "error") {
                    error(`Failed to set orientation to Portrait: ${res.error}`);
                }
            })
            .catch(() => {
                error("Error setting orientation to Portrait");
            });

        if (car) {
            await commands
                .disconnectCar(car.id)
                .then(async () => {
                    connectionStatus = "Disconnected";

                    await disconnect();
                })
                .catch((err) => {
                    error(`Error disconnecting on destroy: ${err}`);
                });
        }

        // close local joystick websocket
        closeJoystickWs();

        // clear any hold interval
        if (holdIntervalId != null) {
            clearInterval(holdIntervalId);
            holdIntervalId = null;
        }

        // Stop camera stream automatically
        if (car?.ip) {
            const result = await stopCamera(car.ip);
            if (result.success) {
                isStreaming = false;
            }
        }
    });

    async function connect() {
        if (!car) return;

        f1DiscoveryService.selectedConnection = "Connecting";
        await commands.connectToCar(car.id).then((res) => {
            if (res.status === "error") {
                error(`Failed to connect: ${res.error}`);
                connectionStatus = "Disconnected";
                return;
            }
        });

        await f1DiscoveryService.getCarById(car.id).then((car) => {
            f1DiscoveryService.selectedConnection =
                car?.connectionStatus === "Connected" ? "Connected" : "Connecting";
        });
    }

    async function disconnect() {
        if (!car) return;

        await commands.disconnectCar(car.id);
        f1DiscoveryService.selectCar(undefined);
        goto("/#/");
    }
</script>

<div class="relative min-h-screen p-6">
    <div class="flex items-center justify-between">
        <div class="flex items-center">
            <button
                class="rounded border border-white/20 bg-transparent px-3 py-1 text-white"
                onclick={async () => {
                    // set portrait, stop joystick service (rust) and close JS websocket before navigating
                    await commands.setOrientation("Portrait").catch((e) => {
                        error(`Failed to set orientation to Portrait on back: ${e}`);
                    });

                    await commands.stopJoystickService().catch((e) => {
                        info(`Failed to stop joystick service via commands API: ${e}`);
                    });

                    // close local joystick websocket (JS sender)
                    try {
                        closeJoystickWs();
                    } catch (e) {
                        info(`Error closing joystick WS on back: ${e}`);
                    }

                    await vibrate(100).then(() => goto("/#"));
                }}>
                <ChevronLeft />
            </button>

            <h1 class="font-f1 ml-4 text-2xl text-white">Car #{carNumber}</h1>
        </div>

        <div class="flex flex-1 justify-center">
            {#if car}
                <div class="whitespace-nowrap text-sm text-gray-400">{car.driver} - {car.team}</div>
            {/if}
        </div>

        <div class="ml-4">
            <div
                class="rounded-full px-3 py-1 text-sm font-medium text-white"
                class:!bg-red-600={connectionStatus === "Disconnected"}
                class:!bg-yellow-500={connectionStatus === "Connecting"}
                class:!bg-green-600={connectionStatus === "Connected"}>
                {connectionStatus}
            </div>
        </div>
    </div>

    {#if isStreaming && car?.ip}
        <div class="absolute left-1/2 top-20 -translate-x-1/2 transform">
            <VideoStream streamUrl={`http://${car.ip}:8081/stream`} />
        </div>
    {/if}

    <div class="absolute bottom-6 left-6">
        <Joystick
            size={200}
            knobSize={56}
            x={leftX}
            y={leftY}
            start={() => {
                // begin periodic sends while held
                if (holdIntervalId == null) {
                    holdIntervalId = setInterval(
                        () => sendJoystickSample(rightX, leftY),
                        1000 / HOLD_SEND_HZ
                    ) as unknown as number;
                }
            }}
            input={(_x, y) => {
                leftY = y;
                sendJoystickSample(rightX, leftY);
            }}
            end={() => {
                leftY = 0;
                sendJoystickSample(rightX, leftY);

                // stop periodic sends
                if (holdIntervalId != null) {
                    clearInterval(holdIntervalId);
                    holdIntervalId = null;
                }
            }} />
    </div>

    <div class="absolute bottom-6 right-6">
        <Joystick
            size={200}
            knobSize={56}
            x={rightX}
            y={rightY}
            start={() => {
                if (holdIntervalId == null) {
                    holdIntervalId = setInterval(
                        () => sendJoystickSample(rightX, leftY),
                        1000 / HOLD_SEND_HZ
                    ) as unknown as number;
                }
            }}
            input={(x, _y) => {
                rightX = x;
                sendJoystickSample(rightX, leftY);
            }}
            end={() => {
                rightX = 0;
                sendJoystickSample(rightX, leftY);

                if (holdIntervalId != null) {
                    clearInterval(holdIntervalId);
                    holdIntervalId = null;
                }
            }} />
    </div>
</div>
