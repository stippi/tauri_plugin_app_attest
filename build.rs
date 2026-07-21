fn main() {
    // No webview-facing commands: the plugin is only called from Rust
    // (trial registration), so the command allowlist stays empty.
    tauri_plugin::Builder::new(&[]).ios_path("ios").build();
}
