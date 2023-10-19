//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//
// https://www.swiftbysundell.com/articles/async-and-concurrent-forEach-and-map/

import Foundation

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

extension Sequence {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}
