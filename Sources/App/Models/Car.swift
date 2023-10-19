//
//  Car.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Fluent
import Vapor

final class Car: Model, Content {
    static let schema = "car"
    
    // Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: Keys.number.fieldKey)
    var number: String
    
    @Field(key: Keys.model.fieldKey)
    var model: String?
    
    // When this House was created
    @Timestamp(key: Keys.createdAt.fieldKey, on: .create)
    var createdAt: Date?
    
    // When this House was last updated
    @Timestamp(key: Keys.updatedAt.fieldKey, on: .update)
    var updatedAt: Date?
    
    
    @Parent(key: Keys.resident.fieldKey)
    var resident: Resident
    
    @Parent(key: Keys.house.fieldKey)
    var house: House
    
    enum Keys: String {
        case number = "number"
        case model = "model"
        case resident = "resident_id"
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
    
    init() { }
    
    init(id: UUID? = nil, number: String, model: String?, residentId: Resident.IDValue, houseId: House.IDValue) {
        self.id = id
        self.number = number.lowercased()
        self.model = model
        self.$resident.id = residentId
        self.$house.id = houseId
    }
    
    func description() -> String {
        var description: String = ""
        
        description += "Автомобиль 🚘 "
        if let model {
            description += "модели " + model
        }
        
        description += " с номером " + number.uppercased()
        
        return description
    }
}

extension Car: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add(Keys.number.validationKey, as: String.self, is: .count(7...9) && .alphanumeric)
    }
}

extension Car {
    struct NewCar {
        var number: String?
        var model: String?
        var residentId: Int64
        var houseId: Int64
        
        func build() -> Car? {
            guard
                let number = self.number,
                let model = self.model
            else { return nil }
            return Car(number: number, model: model, residentId: self.residentId, houseId: self.houseId)
        }
    }
}
