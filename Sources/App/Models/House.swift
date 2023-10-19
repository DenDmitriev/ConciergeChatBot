//
//  House.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Fluent
import Vapor

final class House: Model, Content {
    static let schema = "homes"
    
    enum Keys: String {
        case name = "name"
        case firstFloor = "first_floor"
        case lastFloor = "last_floor"
        case apartPerFloor = "apart_per_floor"
        case firstApart = "first_apart"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        
        var fieldKey: FieldKey {
            return FieldKey(stringLiteral: self.rawValue)
        }
        
        var validationKey: ValidationKey {
            return ValidationKey(stringLiteral: self.rawValue)
        }
    }
    
    // Unique identifier
    @ID(custom: .id)
    var id: Int64?
    
    @Field(key: Keys.name.fieldKey)
    var name: String
    
    // Number of the floor on which the apartment count begins
    @Field(key: Keys.firstFloor.fieldKey)
    var firstFloor: Int8
    
    @Field(key: Keys.lastFloor.fieldKey)
    var lastFloor: Int8
    
    @Field(key: Keys.apartPerFloor.fieldKey)
    var apartPerFloor: Int8
    
    @Field(key: Keys.firstApart.fieldKey)
    var firstApart: Int16
    
    // When this House was created
    @Timestamp(key: Keys.createdAt.fieldKey, on: .create)
    var createdAt: Date?
    
    // When this House was last updated
    @Timestamp(key: Keys.updatedAt.fieldKey, on: .update)
    var updatedAt: Date?
    
    @Children(for: \.$house)
    var residents: [Resident]
    
    @Children(for: \.$house)
    var cars: [Car]
    
    init() { }
    
    init(id: Int64, name: String, firstFloor: Int8, lastFloor: Int8, apartPerFlor: Int8, firstApart: Int16) {
        self.id = id
        self.name = name
        self.firstFloor = firstFloor
        self.lastFloor = lastFloor
        self.apartPerFloor = apartPerFlor
        self.firstApart = firstApart
    }
    
    func description() -> String {
        var description: String = ""
        
        description += "Название чата" + " - " + name
        description += "\n"
        
        description += "Первый жилой этаж" + " - " + "\(firstFloor)"
        description += "\n"
    
        description += "Последний жилой этаж" + " - " + "\(lastFloor)"
        description += "\n"
        
        description += "Квартир на этаж" + " - " + "\(apartPerFloor)"
        description += "\n"
        
        description += "Отсчет квартир от" + " - " + "\(firstApart)"
        description += "\n"
        
        if let date = updatedAt ?? createdAt {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ru_RU")
            dateFormatter.timeStyle = .medium
            dateFormatter.dateStyle = .medium
            let dateString = dateFormatter.string(from: date)
            description += "Дата создания: " + dateString
        }
        
        return description
    }
}

extension House {
    struct NewHouse {
        var id: Int64
        var name: String?
        var firstFloor: Int?
        var lastFloor: Int?
        var apartPerFloor: Int?
        var firstApart: Int?
        
        func description() -> String {
            var description: String = ""
            if let name {
                description += "Название чата" + " - " + name
                description += "\n"
            }
            if let firstFloor {
                description += "Первый жилой этаж" + " - " + "\(firstFloor)"
                description += "\n"
            }
            if let lastFloor {
                description += "Последний жилой этаж" + " - " + "\(lastFloor)"
                description += "\n"
            }
            if let apartPerFloor {
                description += "Квартир на этаж" + " - " + "\(apartPerFloor)"
                description += "\n"
            }
            if let firstApart {
                description += "Отсчет квартир от" + " - " + "\(firstApart)"
                description += "\n"
            }
            
            return description
        }
        
        func build() -> House? {
            guard
                let name = self.name,
                let firstFloor = self.firstFloor,
                let lastFloor = self.lastFloor,
                let apartPerFlor = self.apartPerFloor,
                let firstApart = self.firstApart
            else { return nil }
            
            return House(
                id: self.id,
                name: name,
                firstFloor: Int8(downcast: firstFloor),
                lastFloor: Int8(downcast: lastFloor),
                apartPerFlor: Int8(downcast: apartPerFlor),
                firstApart: Int16(downcast: firstApart)
            )
        }
    }
}

extension House: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add(Keys.firstFloor.validationKey, as: Int8.self, is: .range(0...127))
        validations.add(Keys.lastFloor.validationKey, as: Int8.self, is: .range(1...127))
        validations.add(Keys.apartPerFloor.validationKey, as: Int8.self, is: .range(1...127))
    }
}
