//
//  HouseError.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Foundation

enum HouseError: Error {
    case id, some(function: String), format
}

extension HouseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .id:
            return "Дом не найден"
        case .some(let function):
            return "Извините, у меня ошибка. Попробуйте снова.\nОписание: \(function)"
        case .format:
            return "Не верный формат. Попробуйте снова."
        }
    }
}
