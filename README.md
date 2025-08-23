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

---

## 🛠 Development Environment

```bash

paru -S aarch64-linux-musl arm-none-eabi-gcc
sudo pacman -S aarch64-linux-gnu-gcc
rustup target add aarch64-unknown-linux-musl
rustup target add thumbv7em-none-eabihf

```
