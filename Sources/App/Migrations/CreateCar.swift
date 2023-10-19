//
//  CreateCar.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Fluent

struct CreateCar: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Car.schema)
            .id()
            .field(Car.Keys.number.fieldKey, .string, .required)
            .field(Car.Keys.model.fieldKey, .string)
            .field(Car.Keys.resident.fieldKey, .int, .required, .references(Resident.schema, "id"))
            .field(Car.Keys.house.fieldKey, .int, .required, .references(House.schema, "id"))
            .field(Car.Keys.createdAt.fieldKey, .date)
            .field(Car.Keys.updatedAt.fieldKey, .date)
            .foreignKey(Car.Keys.resident.fieldKey, references: Resident.schema, "id", onDelete: .cascade)
            .foreignKey(Car.Keys.house.fieldKey, references: House.schema, "id", onDelete: .cascade)
            .unique(on: Car.Keys.number.fieldKey)
            .create()
        
    }

    func revert(on database: Database) async throws {
        try await database.schema(Car.schema).delete()
    }
    
}

