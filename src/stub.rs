//! Stub for every platform without App Attest (macOS, Windows, Linux,
//! Android, iOS Simulator builds are handled at runtime on iOS itself).

use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::models::Attestation;

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<AppAttest<R>> {
    Ok(AppAttest { _app: app.clone() })
}

pub struct AppAttest<R: Runtime> {
    _app: AppHandle<R>,
}

impl<R: Runtime> AppAttest<R> {
    pub fn is_supported(&self) -> crate::Result<bool> {
        Ok(false)
    }

    pub fn attest(&self, _challenge: &[u8]) -> crate::Result<Attestation> {
        Err(crate::Error::NotSupported)
    }
}
