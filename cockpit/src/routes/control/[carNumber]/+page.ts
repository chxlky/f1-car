import type { PageLoad } from "./$types";
import { redirect } from "@sveltejs/kit";
import { f1DiscoveryService } from "$lib/services/DiscoveryService.svelte";

export const load = (async ({ params }: { params: Record<string, string> }) => {
    const num = Number(params.carNumber);
    if (Number.isNaN(num)) throw redirect(302, "/");

    try {
        await f1DiscoveryService.checkIsRunning();
        await f1DiscoveryService.refreshCars();
    } catch {
        // ignore and redirect if not found
    }

    const found = f1DiscoveryService.getCarByNumber(num);
    if (!found) throw redirect(302, "/");

    return { carNumber: params.carNumber };
}) satisfies PageLoad;
