//! Apple App Attest plugin for Tauri.
//!
//! Wraps `DCAppAttestService` (iOS 14+): generates a hardware-bound key in
//! the Secure Enclave, persists its key id (Keychain, device-only) and
//! produces attestation objects a server can verify against Apple's App
//! Attest root CA.  One device keeps one key: repeated [`AppAttest::attest`]
//! calls reuse the stored key id.
//!
//! On every platform except iOS, [`AppAttest::is_supported`] returns `false`
//! and [`AppAttest::attest`] fails with [`Error::NotSupported`].  There is no
//! webview API — the plugin is called from Rust only.

use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

mod error;
mod models;

#[cfg(target_os = "ios")]
mod mobile;
#[cfg(not(target_os = "ios"))]
mod stub;

pub use error::{Error, Result};
#[cfg(target_os = "ios")]
use mobile::AppAttest;
#[cfg(not(target_os = "ios"))]
use stub::AppAttest;

pub trait AppAttestExt<R: Runtime> {
    fn app_attest(&self) -> &AppAttest<R>;
}

impl<R: Runtime, T: Manager<R>> AppAttestExt<R> for T {
    fn app_attest(&self) -> &AppAttest<R> {
        self.state::<AppAttest<R>>().inner()
    }
}

pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("app-attest")
        .setup(|app, api| {
            #[cfg(target_os = "ios")]
            let app_attest = mobile::init(app, api)?;
            #[cfg(not(target_os = "ios"))]
            let app_attest = stub::init(app, api)?;
            app.manage(app_attest);
            Ok(())
        })
        .build()
}
