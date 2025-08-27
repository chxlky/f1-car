export async function startCamera(ip: string): Promise<{ success: boolean; status: string }> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=start`);
        if (response.ok) {
            const text = await response.text();
            console.log(text);
            return { success: true, status: "Running" };
        } else {
            console.error("Failed to start camera");
            return { success: false, status: "Error" };
        }
    } catch (error) {
        console.error("Error starting camera:", error);
        return { success: false, status: "Error" };
    }
}

export async function stopCamera(ip: string): Promise<{ success: boolean; status: string }> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=stop`);
        if (response.ok) {
            const text = await response.text();
            console.log(text);
            return { success: true, status: "Stopped" };
        } else {
            console.error("Failed to stop camera");
            return { success: false, status: "Error" };
        }
    } catch (error) {
        console.error("Error stopping camera:", error);
        return { success: false, status: "Error" };
    }
}

export async function checkStatus(ip: string): Promise<{ success: boolean; status: string }> {
    try {
        const response = await fetch(`http://${ip}:8081/stream?action=status`);
        if (response.ok) {
            const text = await response.text();
            console.log(text);
            if (text.includes("Running")) {
                return { success: true, status: "Running" };
            } else {
                return { success: true, status: "Stopped" };
            }
        } else {
            console.error("Failed to check status");
            return { success: false, status: "Unknown" };
        }
    } catch (error) {
        console.error("Error checking status:", error);
        return { success: false, status: "Unknown" };
    }
}
