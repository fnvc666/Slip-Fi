//
//  HistoryStore.swift
//  Slip-Fi
//
//  Created by Pavel Pavel on 02/08/2025.
//
import Foundation

final class HistoryStore {
    static let shared = HistoryStore()
    private let key = "swapHistory"
    private let queue = DispatchQueue(label: "history.store.queue", qos: .utility)

    func append(_ entry: TransactionModel) {
        queue.async {
            var list = self.load()
            list.append(entry)
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: self.key)
            }
        }
    }

    func load() -> [TransactionModel] {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([TransactionModel].self, from: data) {
            return list
        }
        return []
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

