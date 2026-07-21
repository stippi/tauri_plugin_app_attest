use base64::Engine;
use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::models::{Attestation, SupportedResponse};

tauri::ios_plugin_binding!(init_plugin_app_attest);

pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> crate::Result<AppAttest<R>> {
    let handle = api.register_ios_plugin(init_plugin_app_attest)?;
    Ok(AppAttest(handle))
}

pub struct AppAttest<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> AppAttest<R> {
    /// Whether the device supports App Attest (false e.g. in the Simulator).
    pub fn is_supported(&self) -> crate::Result<bool> {
        let response: SupportedResponse = self.0.run_mobile_plugin("isSupported", ())?;
        Ok(response.supported)
    }

    /// Attest the device key over `challenge`.
    ///
    /// The Swift side computes `clientDataHash = SHA256(challenge)` over
    /// exactly these bytes — the verifying server must hash the identical
    /// byte string.  Reuses the persisted key id when present; a fresh key
    /// is generated (and persisted) on first use or when the stored key
    /// was invalidated.
    ///
    /// Blocks until `DCAppAttestService` finishes (network round-trip to
    /// Apple) — call from a blocking-friendly context.
    pub fn attest(&self, challenge: &[u8]) -> crate::Result<Attestation> {
        let args = serde_json::json!({
            "challenge": base64::engine::general_purpose::STANDARD.encode(challenge),
        });
        self.0.run_mobile_plugin("attest", args).map_err(Into::into)
    }
}
