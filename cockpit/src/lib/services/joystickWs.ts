import { info, error, debug } from "@tauri-apps/plugin-log";

let ws: WebSocket | null = null;
let wsRetryTimer: number | null = null;
let wsConnectAttempts = 0;
const WS_MAX_RETRIES = 30;
const WS_RETRY_MS = 200; // retry every 200ms

export function startJoystickWs(port = 9001) {
    const addr = `ws://127.0.0.1:${port}`;
    if (ws && ws.readyState === WebSocket.OPEN) return;
    if (wsRetryTimer != null) return;

    wsConnectAttempts = 0;

    const tryConnect = () => {
        wsConnectAttempts += 1;
        try {
            ws = new WebSocket(addr);
            ws.binaryType = "arraybuffer";
            ws.onopen = () => {
                info(`Joystick WS open: ${addr}`);
                if (wsRetryTimer != null) {
                    clearTimeout(wsRetryTimer);
                    wsRetryTimer = null;
                }
            };
            ws.onclose = () => {
                info("Joystick WS closed");
                ws = null;
                if (wsConnectAttempts < WS_MAX_RETRIES) {
                    wsRetryTimer = window.setTimeout(tryConnect, WS_RETRY_MS) as unknown as number;
                } else {
                    error("Joystick WS: max retries exceeded");
                    wsRetryTimer = null;
                }
            };
            ws.onerror = (e) => {
                error(`Joystick WS error: ${e}`);
                if (ws) {
                    try {
                        ws.close();
                    } catch (err) {
                        error(`Error closing ws after error: ${err}`);
                    }
                }
                ws = null;
                if (wsConnectAttempts < WS_MAX_RETRIES) {
                    wsRetryTimer = window.setTimeout(tryConnect, WS_RETRY_MS) as unknown as number;
                } else {
                    error("Joystick WS: max retries exceeded");
                    wsRetryTimer = null;
                }
            };
        } catch (_e) {
            error(`Failed to start joystick WS: ${_e}`);
            ws = null;
            if (wsConnectAttempts < WS_MAX_RETRIES) {
                wsRetryTimer = window.setTimeout(tryConnect, WS_RETRY_MS) as unknown as number;
            } else {
                error("Joystick WS: max retries exceeded");
                wsRetryTimer = null;
            }
        }
    };

    tryConnect();
}

export function closeJoystickWs() {
    if (ws) {
        try {
            ws.close();
        } catch (err) {
            error(`Error closing ws: ${err}`);
        }
        ws = null;
    }
    if (wsRetryTimer != null) {
        clearTimeout(wsRetryTimer);
        wsRetryTimer = null;
    }
}

export function sendJoystickSample(steering: number, throttle: number) {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;

    const xi = Math.max(-1, Math.min(1, steering));
    const yi = Math.max(-1, Math.min(1, throttle));
    const si = Math.round(xi * 32767);
    const ti = Math.round(yi * 32767);

    const buf = new ArrayBuffer(4);
    const dv = new DataView(buf);

    dv.setInt16(0, si, true);
    dv.setInt16(2, ti, true);

    try {
        ws.send(buf);
    } catch (err) {
        debug(`Joystick WS send error: ${err}`);
    }
}
