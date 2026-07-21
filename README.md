# tauri-plugin-app-attest

Apple App Attest (`DCAppAttestService`) for Tauri 2 — Rust-only API, no
webview commands.

## What it does

- `app.app_attest().is_supported()` — `true` only on real iOS devices
  (not in the Simulator, not on macOS/desktop).
- `app.app_attest().attest(challenge)` — attests the device key over the
  given challenge bytes and returns `{ key_id, attestation_b64 }` for
  server-side verification against Apple's App Attest root CA.

The Swift side computes `clientDataHash = SHA256(challenge)` over exactly
the bytes passed in; the verifying server must hash the identical byte
string when checking the nonce binding.

One device keeps one App Attest key: the generated key id is persisted in
the Keychain (device-only, survives reinstalls) and reused on every call.
If Apple reports the stored key as invalid (e.g. after a device restore),
the plugin generates a fresh key once and retries.

`attest()` blocks until Apple's servers answer — call it from a
blocking-friendly context (e.g. `tauri::async_runtime::spawn_blocking`).

## Platforms

| Platform | Behaviour |
|----------|-----------|
| iOS (device) | Full support (iOS 14+) |
| iOS (Simulator) | `is_supported() == false`, `attest` rejects |
| macOS / Windows / Linux / Android | `is_supported() == false`, `attest` returns `Error::NotSupported` |

## Usage

```rust
use tauri_plugin_app_attest::AppAttestExt;

tauri::Builder::default()
    .plugin(tauri_plugin_app_attest::init())
    // ...

let attestation = app.app_attest().attest(challenge_bytes)?;
```
