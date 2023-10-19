//
//  BlockedCar.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Fluent
import Vapor

final class BlockedCar: Model, Content {
    static let schema = "blocked_car"
    
    enum Keys: String {
        case driver = "driver"
        case number = "number"
        case createdAt = "created_at"
        case house = "house_id"
        
        var fieldKey: FieldKey {
            return FieldKey(stringLiteral: self.rawValue)
        }
        
        var validationKey: ValidationKey {
            return ValidationKey(stringLiteral: self.rawValue)
        }
    }
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: Keys.driver.fieldKey)
    var driver: Int64
    
    @Field(key: Keys.number.fieldKey)
    var number: String
    
    // When this car was created
    @Timestamp(key: Keys.createdAt.fieldKey, on: .create)
    var createdAt: Date?
    
    @Parent(key: Keys.house.fieldKey)
    var house: House
    
    init() { }
    
    init(id: UUID? = nil, driver: Int64, number: String, houseId: House.IDValue) {
        self.id = id
        self.driver = driver
        self.number = number
        self.$house.id = houseId
    }
}
