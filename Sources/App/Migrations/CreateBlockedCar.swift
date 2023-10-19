//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Fluent

final class CreateBlockedCar: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(BlockedCar.schema)
            .id()
            .field(BlockedCar.Keys.driver.fieldKey, .int64, .required)
            .field(BlockedCar.Keys.number.fieldKey, .string, .required)
            .field(BlockedCar.Keys.house.fieldKey, .int, .required, .references(House.schema, "id"))
            .foreignKey(BlockedCar.Keys.house.fieldKey, references: House.schema, "id", onDelete: .cascade)
            .field(BlockedCar.Keys.createdAt.fieldKey, .date)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(BlockedCar.schema).delete()
    }
}
