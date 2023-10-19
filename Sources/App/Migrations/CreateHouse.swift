//
//  CreateHouse.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Fluent

struct CreateHouse: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(House.schema)
            .field("id", .int64, .identifier(auto: false))
            .field(House.Keys.name.fieldKey, .string, .required)
            .field(House.Keys.firstFloor.fieldKey, .int8, .required)
            .field(House.Keys.lastFloor.fieldKey, .int8, .required)
            .field(House.Keys.apartPerFloor.fieldKey, .int8, .required)
            .field(House.Keys.firstApart.fieldKey, .int16, .required)
            .field(House.Keys.createdAt.fieldKey, .date)
            .field(House.Keys.updatedAt.fieldKey, .date)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(House.schema).delete()
    }
}
