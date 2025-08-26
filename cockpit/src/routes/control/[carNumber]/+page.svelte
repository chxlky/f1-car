<script lang="ts">
    import { page } from "$app/state";
    import { goto } from "$app/navigation";
    import { onMount, onDestroy } from "svelte";
    import { type ConnectionStatus, type F1Car, commands } from "$lib/bindings";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import { startJoystickWs, closeJoystickWs, sendJoystickSample } from "$lib/services/joystickWs";
    import { ChevronLeft } from "@lucide/svelte";
    import { vibrate } from "@tauri-apps/plugin-haptics";
    import Joystick from "$lib/components/Joystick.svelte";

    let { carNumber } = page.params;

    let car = $state<F1Car | null>(null);
    let connectionStatus = $state<ConnectionStatus>("Disconnected");

    let leftX = $state(0);
    let leftY = $state(0); // throttle

    let rightX = $state(0); // steering
    let rightY = $state(0);

    let holdIntervalId = $state<number | null>(null);
    const HOLD_SEND_HZ = 20; // send while held at 20Hz

    onMount(async () => {
        await commands
            .setOrientation("Landscape")
            .then(async (res) => {
                if (res.status === "error") {
                    console.error("Failed to set orientation to Landscape:", res.error);
                }

                car = f1DiscoveryService.getCarByNumber(Number(carNumber)) ?? null;
                f1DiscoveryService.selectCar(car?.id);

                if (car?.ip) {
                    const radioAddr = `${car.ip}:8080`;
                    await commands
                        .startJoystickService(9001, radioAddr)
                        .then((res) => {
                            if (res.status === "error") {
                                console.error("Failed to start joystick service:", res.error);
                            } else {
                                console.log("Joystick service started for", radioAddr);
                            }

                            // open a local websocket to the Tauri joystick service so UI samples get forwarded
                            startJoystickWs();
                        })
                        .catch((e: unknown) =>
                            console.error("Failed to start joystick service:", e)
                        );
                }

                await connect().then(() => console.log("Connected to car", car?.number));
            })
            .catch(() => {
                console.error("Error setting orientation to Landscape");
            });
    });

    onDestroy(async () => {
        await commands
            .setOrientation("Portrait")
            .then((res) => {
                if (res.status === "error") {
                    console.error("Failed to set orientation to Portrait:", res.error);
                }
            })
            .catch(() => {
                console.error("Error setting orientation to Portrait");
            });

        if (car) {
            await commands
                .disconnectCar(car.id)
                .then(async () => {
                    connectionStatus = "Disconnected";

                    await disconnect();
                })
                .catch((err) => {
                    console.error("Error disconnecting on destroy:", err);
                });
        }

        // close local joystick websocket
        closeJoystickWs();

        // clear any hold interval
        if (holdIntervalId != null) {
            clearInterval(holdIntervalId);
            holdIntervalId = null;
        }
    });

    async function connect() {
        if (!car) return;

        f1DiscoveryService.selectedConnection = "Connecting";
        await commands.connectToCar(car.id).then((res) => {
            if (res.status === "error") {
                console.error("Failed to connect:", res.error);
                connectionStatus = "Disconnected";
                return;
            }
        });

        await f1DiscoveryService.getCarById(car.id).then((car) => {
            f1DiscoveryService.selectedConnection =
                (car?.connection_status as any) === "Connected" ? "Connected" : "Connecting";
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
                        console.error("Failed to set orientation to Portrait on back:", e);
                    });

                    await commands.stopJoystickService().catch((e) => {
                        console.warn("Failed to stop joystick service via commands API:", e);
                    });

                    // close local joystick websocket (JS sender)
                    try {
                        closeJoystickWs();
                    } catch (e) {
                        console.warn("Error closing joystick WS on back:", e);
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
