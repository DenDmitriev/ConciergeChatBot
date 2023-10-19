//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Fluent
import Vapor

final class Resident: Model, Content {
    static let schema = "residents"
    
    enum Keys: String {
        case name = "name"
        case username = "username"
        case apart = "apart"
        case floor = "floor"
        case house = "house_id"
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
    
    // TG username '@name'
    @Field(key: Keys.username.fieldKey)
    var username: String?
    
    @Field(key: Keys.apart.fieldKey)
    var apart: Int16
    
    @Field(key: Keys.floor.fieldKey)
    var floor: Int8
    
    @Parent(key: Keys.house.fieldKey)
    var house: House
    
    @Children(for: \.$resident)
    var cars: [Car]
    
    // When this House was created
    @Timestamp(key: Keys.createdAt.fieldKey, on: .create)
    var createdAt: Date?
    
    // When this House was last updated
    @Timestamp(key: Keys.updatedAt.fieldKey, on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: Int64, name: String, username: String, apart: Int16, floor: Int8, houseID: House.IDValue) {
        self.id = id
        self.name = name
        self.username = username
        self.apart = apart
        self.floor = floor
        self.$house.id = houseID
    }
    
    func description() -> String {
        var description: String = ""
        description += "Вы проживаете на \(floor) этаже"
        description += " в \(apart) квартире."
        description += "\n"
        
        return description
    }
}

extension Resident: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add(Keys.apart.validationKey, as: Int16.self, is: .range(1...32767))
        validations.add(Keys.floor.validationKey, as: Int8.self, is: .range(1...127))
    }
}

extension Resident {
    struct NewResident {
        var id: Int64
        var name: String
        var username: String?
        var apart: Int?
        var floor: Int?
        var house: House.IDValue
        
        func build() -> Resident? {
            guard
                let apart = self.apart,
                let floor = self.floor,
                let username = self.username
            else { return nil }
            return Resident(
                id: self.id,
                name: self.name,
                username: username,
                apart: Int16(downcast: apart),
                floor: Int8(downcast: floor),
                houseID: self.house
            )
        }
        
        func description() -> String {
            var description: String = ""
            if let floor {
                description += "Вы проживаете на \(floor) этаже"
            }
            if let apart {
                description += " в \(apart) квартире."
                description += "\n"
            }
            
            return description
        }
    }
}
