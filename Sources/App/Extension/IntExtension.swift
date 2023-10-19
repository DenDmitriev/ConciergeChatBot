//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Foundation

protocol Downcastable {
    init(downcast: Int)
}

extension Int8: Downcastable {
    public init(downcast: Int) {
        let number = downcast > Int8.max ? Int(Int8.max) : downcast
        self = Int8(number)
    }
}

extension Int16: Downcastable {
    public init(downcast: Int) {
        let number = downcast > Int16.max ? Int(Int16.max) : downcast
        self = Int16(number)
    }
}

extension Int64: Downcastable {
    public init(downcast: Int) {
        let number = downcast > Int64.max ? Int(Int64.max) : downcast
        self = Int64(number)
    }
}

extension Int: Downcastable {
    public init(downcast: Int) {
        self = downcast
    }
}

extension Int {
    var isApart: Bool {
        // Думаю что нет квартир больше 5000
        if !(1...5000 ~= self) {
            return false
        }
        return true
    }
}
