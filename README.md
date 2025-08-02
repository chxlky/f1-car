# F1 Car Project

A modular, real-time, and low-level Rust-based RC F1 car project, powered by a Raspberry Pi 4B and an STM32 microcontroller.

This project is structured to separate concerns between real-time control, networking, and frontend interaction. It uses a modern Rust toolchain, an RTOS for embedded control, and a Flutter app for user interaction.

## 📦 Project Structure

```text
f1-car/
├── telemetry/ # Shared Rust types and protocols
├── powertrain/ # STM32 firmware (Rust + Embassy RTOS)
├── radio/ # Raspberry Pi app (networking, camera relay)
├── cockpit/ # Flutter app (UI, discovery, control)
├── logbook/ # Documentation and development notes
```

## 🔧 Responsibilities

### 📻 `radio/` (Raspberry Pi 4B)

- Wi-Fi connectivity
- UDP interface to control the car
- Video stream relay from Pi Camera
- Relays control inputs to STM32 over UART
- Receives telemetry from STM32

### ⚙️ `powertrain/` (STM32 MCU)

- Runs [Embassy](https://embassy.dev) RTOS
- Handles motor control via L298N driver
- Reads IMU data for orientation sensing
- Sends telemetry back to the Pi over UART

### 📱 `cockpit/` (Flutter App)

- Flutter-powered mobile UI
- Receives live telemetry data
- Displays camera feed
- Sends control inputs (steering, throttle) to the car
- Powered by [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)

---

## 🛠 Development Environment

1) Install [Nix Package Manager](https://nixos.org/download/)
2) Enable flakes in Nix config
3) Run `nix develop` in the project root to enter the development shell
