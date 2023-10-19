//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 16.10.2023.
//

import Foundation

enum TransactionError: Error {
    case alreadyExist(name: String)
    case notFound
    case cantSave
    case unknown(description: String)
}

extension TransactionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .alreadyExist(let name):
            return "Дом для чата - \(name) уже существует."
        case .notFound:
            return "Нет данных для дома. Попробуйте снова позднее."
        case .cantSave:
            return "Не удалось записать. Попробуйте снова позднее."
        case .unknown(let description):
            return description
        }
    }
}
