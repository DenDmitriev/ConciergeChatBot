//
//  ResidentError.swift
//  
//
//  Created by Denis Dmitriev on 16.10.2023.
//

import Foundation


enum ResidentError: Error {
    case id, some(function: String), format, empty
}

extension ResidentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .id:
            return "Житель не найден"
        case .some(let function):
            return "Извините, у меня ошибка. Попробуйте снова.\nОписание: \(function)"
        case .format:
            return "Не верный формат. Попробуйте снова."
        case .empty:
            return "Список пуст."
        }
    }
}
