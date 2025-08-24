<script lang="ts">
    import { page } from "$app/state";
    import { onMount, onDestroy } from "svelte";
    import { type ConnectionStatus, type F1Car, commands } from "$lib/bindings";
    import Joystick from "$lib/components/Joystick.svelte";
    import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";
    import { goto } from "$app/navigation";
    import { ChevronLeft } from "@lucide/svelte";
    import { vibrate } from "@tauri-apps/plugin-haptics";

    let { carNumber } = page.params;

    let car = $state<F1Car | null>(null);
    let connectionStatus = $state<ConnectionStatus>("Disconnected");

    onMount(async () => {
        await commands
            .setOrientation("Landscape")
            .then(async (res) => {
                if (res.status === "error") {
                    console.error("Failed to set orientation to Landscape:", res.error);
                }

                car = f1DiscoveryService.getCarByNumber(Number(carNumber)) ?? null;
                f1DiscoveryService.selectCar(car?.id);

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

        try {
            if (car) {
                await commands.disconnectCar(car.id).then(async () => {
                    connectionStatus = "Disconnected";

                    await disconnect();
                });
            }
        } catch (err) {
            console.error("Error disconnecting on destroy:", err);
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
                    await commands.setOrientation("Portrait").catch((e) => {
                        console.error("Failed to set orientation to Portrait on back:", e);
                    });

                    await vibrate(100);
                    goto("/#/");
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
            on:input={(event) => {
                const { x, y } = event.detail;
                console.log("left joystick", x, y);
            }}
            on:end={() => {
                /* stop */
            }} />
    </div>

    <div class="absolute bottom-6 right-6">
        <Joystick
            size={200}
            on:input={(event) => {
                const { x, y } = event.detail;
                console.log("right joystick", x, y);
            }}
            on:end={() => {
                /* stop */
            }} />
    </div>
</div>
