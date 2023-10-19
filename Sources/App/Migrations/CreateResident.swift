//
//  CreateResident.swift
//  
//
//  Created by Denis Dmitriev on 16.10.2023.
//

import Fluent

struct CreateResident: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Resident.schema)
            .field("id", .int64, .identifier(auto: false))
            .field(Resident.Keys.name.fieldKey, .string, .required)
            .field(Resident.Keys.username.fieldKey, .string)
            .field(Resident.Keys.apart.fieldKey, .int16, .required)
            .field(Resident.Keys.floor.fieldKey, .int8, .required)
            .field(Resident.Keys.house.fieldKey, .int, .required, .references(House.schema, "id"))
            .foreignKey(Resident.Keys.house.fieldKey, references: House.schema, "id", onDelete: .cascade)
            .field(Resident.Keys.createdAt.fieldKey, .date)
            .field(Resident.Keys.updatedAt.fieldKey, .date)
            .unique(on: Resident.Keys.username.fieldKey)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Resident.schema).delete()
    }
}
