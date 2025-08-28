import { info, error } from "@tauri-apps/plugin-log";

type CameraActionStatus = "Success" | "Error";
type CameraOperationStatus = "Running" | "Stopped" | "Error";
type CameraCheckStatus = "Running" | "Stopped" | "Unknown";

interface CameraResponse {
    success: boolean;
    status: CameraActionStatus;
    text?: string;
}

interface CameraOperationResponse {
    success: boolean;
    status: CameraOperationStatus;
}

interface CameraCheckResponse {
    success: boolean;
    status: CameraCheckStatus;
}

async function cameraRequest(ip: string, action: string): Promise<CameraResponse> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=${action}`);
        const text = await response.text();

        if (response.ok) {
            info(text);
            return { success: true, status: "Success", text };
        } else {
            error(`Camera ${action} failed`);
            return { success: false, status: "Error", text };
        }
    } catch (err) {
        error(`Error during camera ${action}: ${err}`);
        return { success: false, status: "Error" };
    }
}

export async function startCamera(ip: string): Promise<CameraOperationResponse> {
    const result = await cameraRequest(ip, "start");
    return {
        success: result.success,
        status: result.success ? "Running" : "Error"
    };
}

export async function stopCamera(ip: string): Promise<CameraOperationResponse> {
    const result = await cameraRequest(ip, "stop");
    return {
        success: result.success,
        status: result.success ? "Stopped" : "Error"
    };
}

export async function checkStatus(ip: string): Promise<CameraCheckResponse> {
    const result = await cameraRequest(ip, "status");
    if (!result.success) {
        return { success: false, status: "Unknown" };
    }
    if (result.text?.includes("Running")) {
        return { success: true, status: "Running" };
    } else {
        return { success: true, status: "Stopped" };
    }
}
