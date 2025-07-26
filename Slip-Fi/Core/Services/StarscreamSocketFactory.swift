//
//  StarscreamSocketFactory.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 25/07/2025.
//

import Foundation
import WalletConnectRelay
import Starscream


final class StarscreamSocketFactory: WebSocketFactory {
    func create(with url: URL) -> any WebSocketConnecting {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let socket = WebSocket(request: request)
        return StarscreamWebSocketAdapter(socket: socket)
    }
}
