//
//  TxSender.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 27/07/2025.
//
import Foundation
import Combine
import ReownAppKit
import WalletConnectSign
import WalletConnectUtils

@MainActor
final class TxSender {
    static let shared = TxSender()

    private func makeTxObject(
        from userAddress: String,
        to: String,
        data: String,
        valueHex: String?,
        gasHex: String?,
        gasPriceHex: String?,
        preferWalletGasEstimation: Bool
    ) -> [String: Any] {
        var txObj: [String: Any] = [
            "from": userAddress,
            "to":   to,
            "data": data,
            "value": valueHex ?? "0x0"
        ]

        if !preferWalletGasEstimation {
            if let gasHex      { txObj["gas"] = gasHex }
            if let gasPriceHex { txObj["gasPrice"] = gasPriceHex }
        }
        return txObj
    }

    // ===== send swap tx =====
    func send(
        tx: OneInchSwapTx,
        userAddress: String,
        preferWalletGasEstimation: Bool = true
    ) async throws -> String {

        guard let session = AppKit.instance.getSessions().first else {
            throw NSError(domain: "wc", code: -10, userInfo: [NSLocalizedDescriptionKey: "No active wallet session"])
        }
        guard let chain = Blockchain(namespace: "eip155", reference: "137") else {
            throw NSError(domain: "wc", code: -11, userInfo: [NSLocalizedDescriptionKey: "Invalid chain eip155:137"])
        }

        // Конвертация в HEX до сборки объекта
        let valueHex = toHex0x(tx.value) ?? "0x0" // String? -> "0x..."
        let gasHex   = toHex0x(tx.gas)            // Int?    -> "0x..."
        let gpHex    = toHex0x(tx.gasPrice)       // String? -> "0x..."

        let txObj = makeTxObject(
            from: userAddress,
            to:   tx.to,
            data: tx.data,
            valueHex: valueHex,
            gasHex:   gasHex,
            gasPriceHex: gpHex,
            preferWalletGasEstimation: preferWalletGasEstimation
        )

        let request = try WalletConnectSign.Request(
            topic: session.topic,
            method: "eth_sendTransaction",
            params: AnyCodable(any: [txObj]),
            chainId: chain
        )

        AppKit.instance.launchCurrentWallet()
        try? await Task.sleep(nanoseconds: 250_000_000) // 250ms

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            var cancellable: AnyCancellable?
            var done = false

            func finish(_ result: Result<String, Error>) {
                guard !done else { return }
                done = true
                cancellable?.cancel()
                switch result {
                case .success(let hash): cont.resume(returning: hash)
                case .failure(let err):  cont.resume(throwing: err)
                }
            }

            cancellable = AppKit.instance.sessionResponsePublisher.sink { r in
                switch r.result {
                case .response(let anyCodable):
                    let any = anyCodable.value
                    if let hash = any as? String { finish(.success(hash)); return }
                    if let dict = any as? [String: Any], let hash = dict["result"] as? String { finish(.success(hash)); return }
                    if let arr = any as? [Any], let hash = arr.first as? String { finish(.success(hash)); return }
                    finish(.failure(NSError(domain: "wc", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected wallet response"])))
                case .error(let e):
                    finish(.failure(e))
                }
            }

            Task {
                do {
                    try await AppKit.instance.request(params: request)
                } catch {
                    finish(.failure(error))
                }
            }
        }
    }

    // ===== send approve tx =====
    func send(
        approveTx tx: OneInchApproveTx,
        userAddress: String,
        preferWalletGasEstimation: Bool = true
    ) async throws -> String {

        guard let session = AppKit.instance.getSessions().first else {
            throw NSError(domain: "wc", code: -10, userInfo: [NSLocalizedDescriptionKey: "No active wallet session"])
        }
        guard let chain = Blockchain(namespace: "eip155", reference: "137") else {
            throw NSError(domain: "wc", code: -11, userInfo: [NSLocalizedDescriptionKey: "Invalid chain eip155:137"])
        }

        let valueHex = toHex0x(tx.value) ?? "0x0"
        let gasHex   = toHex0x(tx.gas)
        let gpHex    = toHex0x(tx.gasPrice)

        let txObj = makeTxObject(
            from: userAddress,
            to:   tx.to,
            data: tx.data,
            valueHex: valueHex,
            gasHex:   gasHex,
            gasPriceHex: gpHex,
            preferWalletGasEstimation: preferWalletGasEstimation
        )

        let request = try WalletConnectSign.Request(
            topic: session.topic,
            method: "eth_sendTransaction",
            params: AnyCodable(any: [txObj]),
            chainId: chain
        )

        AppKit.instance.launchCurrentWallet()
        try? await Task.sleep(nanoseconds: 250_000_000)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            var cancellable: AnyCancellable?
            var done = false
            func finish(_ result: Result<String, Error>) {
                guard !done else { return }
                done = true
                cancellable?.cancel()
                switch result {
                case .success(let hash): cont.resume(returning: hash)
                case .failure(let err):  cont.resume(throwing: err)
                }
            }
            cancellable = AppKit.instance.sessionResponsePublisher.sink { r in
                switch r.result {
                case .response(let anyCodable):
                    let any = anyCodable.value
                    if let hash = any as? String { finish(.success(hash)); return }
                    if let dict = any as? [String: Any], let hash = dict["result"] as? String { finish(.success(hash)); return }
                    if let arr = any as? [Any], let hash = arr.first as? String { finish(.success(hash)); return }
                    finish(.failure(NSError(domain: "wc", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected wallet response"])))
                case .error(let e):
                    finish(.failure(e))
                }
            }
            Task {
                do {
                    try await AppKit.instance.request(params: request)
                } catch {
                    finish(.failure(error))
                }
            }
        }
    }

    // ===== wait for confirmation =====
    func waitForTransactionConfirmation(
        txHash: String,
        interval: TimeInterval = 4.0,
        maxAttempts: Int = 40
    ) async throws {
        let urlPrefix = "https://api.polygonscan.com/api"
        let apiKey = Secrets.polygonscanKey

        for _ in 0..<maxAttempts {
            guard let url = URL(string: "\(urlPrefix)?module=transaction&action=gettxreceiptstatus&txhash=\(txHash)&apikey=\(apiKey)") else {
                throw NSError(domain: "wait", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Polygonscan URL"])
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = (json?["result"] as? [String: String])?["status"]
            if status == "1" { return }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        throw NSError(domain: "wait", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout while waiting for tx confirmation"])
    }
}

// MARK: - HEX utils

private func toHex0x(_ i: Int?) -> String? {
    guard let i else { return nil }
    return "0x" + String(i, radix: 16)
}

private func toHex0x(_ s: String?) -> String? {
    guard let s, !s.isEmpty else { return nil }
    if s.hasPrefix("0x") { return s }
    if let u = UInt64(s) { return "0x" + String(u, radix: 16) }

    guard var d = Decimal(string: s), d >= 0 else { return nil }
    if d == 0 { return "0x0" }

    let digits = Array("0123456789abcdef")
    var hex = ""
    var sixteen = Decimal(16)
    while d > 0 {
        var q = Decimal(); NSDecimalDivide(&q, &d, &sixteen, .plain)
        var qFloor = Decimal(); NSDecimalRound(&qFloor, &q, 0, .down)
        var t = Decimal(); NSDecimalMultiply(&t, &qFloor, &sixteen, .plain)
        let r = d - t
        let idx = NSDecimalNumber(decimal: r).intValue
        hex = String(digits[idx]) + hex
        d = qFloor
    }
    return "0x" + hex
}
