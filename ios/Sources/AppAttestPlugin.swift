import CryptoKit
import DeviceCheck
import Foundation
import Tauri

private struct AttestArgs: Decodable {
    let challenge: String
}

/// Apple App Attest bridge.
///
/// Persists the generated key id in the Keychain (device-only, survives
/// reinstalls like the app's trial token does) so one device keeps one
/// App Attest key across sessions.
class AppAttestPlugin: Plugin {
    private static let keychainService = "tauri-plugin-app-attest"
    private static let keychainAccount = "app-attest-key-id"

    @objc public func isSupported(_ invoke: Invoke) throws {
        guard #available(iOS 14.0, *) else {
            invoke.resolve(["supported": false])
            return
        }
        invoke.resolve(["supported": DCAppAttestService.shared.isSupported])
    }

    @objc public func attest(_ invoke: Invoke) throws {
        guard #available(iOS 14.0, *) else {
            invoke.reject("App Attest requires iOS 14")
            return
        }
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            invoke.reject("App Attest is not supported on this device")
            return
        }
        let args = try invoke.parseArgs(AttestArgs.self)
        guard let challenge = Data(base64Encoded: args.challenge), !challenge.isEmpty else {
            invoke.reject("Invalid challenge (expected non-empty base64)")
            return
        }
        // The server recomputes this hash over the identical challenge
        // bytes when it verifies the attestation's nonce binding.
        let clientDataHash = Data(SHA256.hash(data: challenge))

        if let keyId = Self.loadKeyId() {
            attestKey(keyId, clientDataHash: clientDataHash, invoke: invoke, storedKey: true)
        } else {
            generateAndAttest(clientDataHash: clientDataHash, invoke: invoke)
        }
    }

    @available(iOS 14.0, *)
    private func generateAndAttest(clientDataHash: Data, invoke: Invoke) {
        DCAppAttestService.shared.generateKey { keyId, error in
            guard let keyId = keyId else {
                invoke.reject("generateKey failed: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            Self.storeKeyId(keyId)
            self.attestKey(keyId, clientDataHash: clientDataHash, invoke: invoke, storedKey: false)
        }
    }

    /// `storedKey`: the key id came from the Keychain (as opposed to one
    /// generated a moment ago). Only such a key is worth retrying without.
    @available(iOS 14.0, *)
    private func attestKey(
        _ keyId: String, clientDataHash: Data, invoke: Invoke, storedKey: Bool
    ) {
        DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash) {
            attestation, error in
            if let attestation = attestation {
                invoke.resolve([
                    "keyId": keyId,
                    "attestationB64": attestation.base64EncodedString(),
                ])
                return
            }
            // A stored key can be unusable in two ways: invalidated on the
            // device (a restore — `.invalidKey`), or generated under the
            // other App Attest environment. The key id is persisted right
            // after `generateKey`, before any attestation succeeded, so a
            // build without the production entitlement leaves a development
            // key behind that a later production build finds in the
            // Keychain — and attesting it against production fails with
            // `.invalidInput`. Either way: drop it and retry once with a
            // freshly generated key.
            if storedKey, let dcError = error as? DCError,
                dcError.code == .invalidKey || dcError.code == .invalidInput
            {
                Self.deleteKeyId()
                self.generateAndAttest(clientDataHash: clientDataHash, invoke: invoke)
                return
            }
            let origin = storedKey ? "stored key" : "fresh key"
            invoke.reject("attestKey failed (\(origin)): \(Self.describe(error))")
        }
    }

    /// `DCError`s by name and code; `localizedDescription` alone reads
    /// "The operation couldn't be completed" for every one of them.
    private static func describe(_ error: Error?) -> String {
        guard let error = error else { return "unknown error" }
        guard let dcError = error as? DCError else { return error.localizedDescription }
        let name: String
        switch dcError.code {
        case .unknownSystemFailure: name = "unknownSystemFailure"
        case .featureUnsupported: name = "featureUnsupported"
        case .invalidInput: name = "invalidInput"
        case .invalidKey: name = "invalidKey"
        case .serverUnavailable: name = "serverUnavailable"
        @unknown default: name = "unknown"
        }
        return "DCError.\(name) (\(dcError.code.rawValue))"
    }

    // MARK: - Keychain persistence

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }

    private static func loadKeyId() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let keyId = String(data: data, encoding: .utf8), !keyId.isEmpty
        else {
            return nil
        }
        return keyId
    }

    private static func storeKeyId(_ keyId: String) {
        let data = Data(keyId.utf8)
        var attributes = baseQuery
        // Device-only: the App Attest key lives in this device's Secure
        // Enclave, so its id must never sync to another device.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(
                baseQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary)
        }
    }

    private static func deleteKeyId() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

@_cdecl("init_plugin_app_attest")
func initPlugin() -> Plugin {
    AppAttestPlugin()
}
