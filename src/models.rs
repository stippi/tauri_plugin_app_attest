use serde::{Deserialize, Serialize};

/// Result of a successful attestation.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Attestation {
    /// Apple's key identifier: base64 of the SHA-256 of the public key.
    /// Stable per device — the plugin persists and reuses the key.
    pub key_id: String,
    /// Base64-encoded CBOR attestation object for server-side verification.
    pub attestation_b64: String,
}

#[cfg(target_os = "ios")]
#[derive(Debug, Deserialize)]
pub(crate) struct SupportedResponse {
    pub supported: bool,
}
