import { info, error } from "@tauri-apps/plugin-log";

export async function startCamera(ip: string): Promise<{ success: boolean; status: string }> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=start`);
        if (response.ok) {
            const text = await response.text();
            info(text);
            return { success: true, status: "Running" };
        } else {
            error("Failed to start camera");
            return { success: false, status: "Error" };
        }
    } catch (err) {
        error(`Error starting camera: ${err}`);
        return { success: false, status: "Error" };
    }
}

export async function stopCamera(ip: string): Promise<{ success: boolean; status: string }> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=stop`);
        if (response.ok) {
            const text = await response.text();
            info(text);
            return { success: true, status: "Stopped" };
        } else {
            error("Failed to stop camera");
            return { success: false, status: "Error" };
        }
    } catch (err) {
        error(`Error stopping camera: ${err}`);
        return { success: false, status: "Error" };
    }
}

export async function checkStatus(ip: string): Promise<{ success: boolean; status: string }> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=status`);
        if (response.ok) {
            const text = await response.text();
            info(text);
            if (text.includes("Running")) {
                return { success: true, status: "Running" };
            } else {
                return { success: true, status: "Stopped" };
            }
        } else {
            error("Failed to check status");
            return { success: false, status: "Unknown" };
        }
    } catch (err) {
        error(`Error checking status: ${err}`);
        return { success: false, status: "Unknown" };
    }
}
