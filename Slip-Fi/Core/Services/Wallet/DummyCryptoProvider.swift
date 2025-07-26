//
//  DummyCryptoProvider.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 26/07/2025.
//

import Foundation
import WalletConnectSigner

// TODO: - Dummy stub
struct DummyCryptoProvider: CryptoProvider {
    func keccak256(_ data: Data) -> Data { data }
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        throw NSError(domain: "crypto", code: 1)
    }
}
