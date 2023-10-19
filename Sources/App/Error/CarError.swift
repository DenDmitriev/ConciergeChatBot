//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Foundation

enum CarError: Error {
    case id, some(function: String), format, empty, length(count: Int), noValue
}

extension CarError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .id:
            return "Автомобили не найдены."
        case .some(let function):
            return "Извините, у меня ошибка. Попробуйте снова.\nОписание: \(function)"
        case .format:
            return "Не верный формат номера автомобиля. Попробуйте снова."
        case .empty:
            return "Пусто"
        case .length(let count):
            return "Не верный формат модели автомобиля. Длина не должна превышать \(count) символов. Попробуйте снова."
        case .noValue:
            return "Не достаточно параметров для сохранения автомобиля"
        }
    }
}
