//
//  StarscreamWebSocketAdapter.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 26/07/2025.
//

import Foundation
import WalletConnectRelay
import Starscream

final class StarscreamWebSocketAdapter: WebSocketConnecting {
    private let socket: WebSocket
    private(set) var isConnected: Bool = false

    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    
    var request: URLRequest {
        get { socket.request }
        set { socket.request = newValue }
    }

    init(socket: WebSocket) {
        self.socket = socket
        self.socket.onEvent = { [weak self] event in
            switch event {
            case .connected:
                self?.isConnected = true
                self?.onConnect?()
            case .disconnected:
                self?.isConnected = false
                self?.onDisconnect?(nil)
            case .text(let text):
                self?.onText?(text)
            case .error(let error):
                self?.isConnected = false
                self?.onDisconnect?(error)
            default:
                break
            }
        }
    }

    func connect() {
        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
    }

    func write(string: String, completion: (() -> Void)?) {
        socket.write(string: string, completion: completion)
    }
}
