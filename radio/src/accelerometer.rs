use std::thread::{self, JoinHandle};
use std::time::Duration;

use adxl345_driver::i2c::Device as AdxlDevice;
use adxl345_driver::{Adxl345Reader, Adxl345Writer};
use anyhow::{Context, Result};
use log::{error, trace};
use tokio_util::sync::CancellationToken;

const SCALE_MULTIPLIER: f64 = 0.004; // 4 mg per LSB -> g
const EARTH_GRAVITY_MS2: f64 = 9.80665;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RawSample {
    pub x: i16,
    pub y: i16,
    pub z: i16,
}

pub struct Accelerometer {
    inner: AdxlDevice,
}

impl Accelerometer {
    pub fn new() -> Result<Self> {
        let mut device = AdxlDevice::new().context("Failed to get instance")?;

        let _id = device.device_id().context("Failed to get device id")?;
        device
            .set_data_format(8)
            .context("Failed to set data format")?;
        device
            .set_power_control(8)
            .context("Failed to turn on measurement mode")?;

        Ok(Self { inner: device })
    }

    pub fn read_raw(&mut self) -> Result<RawSample> {
        let (x, y, z) = self
            .inner
            .acceleration()
            .context("Failed to get acceleration data")?;

        Ok(RawSample { x, y, z })
    }

    pub fn read_ms2(&mut self) -> Result<(f64, f64, f64)> {
        let r = self.read_raw()?;
        let to_ms2 = |v: i16| (v as f64) * SCALE_MULTIPLIER * EARTH_GRAVITY_MS2;

        Ok((to_ms2(r.x), to_ms2(r.y), to_ms2(r.z)))
    }

    pub fn shutdown(&mut self) -> Result<()> {
        self.inner
            .set_power_control(0)
            .context("Failed to turn off measurement mode")?;

        Ok(())
    }

    pub fn start_poller(self, cancel_token: CancellationToken, interval_ms: u64) -> JoinHandle<()> {
        thread::spawn(move || {
            let mut dev = self;
            while !cancel_token.is_cancelled() {
                match dev.read_ms2() {
                    Ok((x, y, z)) => {
                        trace!("accel m/s^2: x={:.3} y={:.3} z={:.3}", x, y, z);
                        // maybe in the future we can calculate the velocity
                    }
                    Err(e) => {
                        error!("accelerometer read error: {e}");
                    }
                }

                thread::sleep(Duration::from_millis(interval_ms));
            }

            let _ = dev.shutdown();
        })
    }
}
