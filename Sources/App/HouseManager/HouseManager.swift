//
//  HouseManager.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Vapor
import Fluent

final class HouseManager {
    let app: Vapor.Application
    
    init(app: Vapor.Application) {
        self.app = app
    }
    
    enum Sort {
        case down, up
    }
    
    func floors(in houseID: House.IDValue, sort: Sort = .down) async throws -> [Int8] {
        guard let house = try await House.query(on: app.db)
            .filter(\.$id == houseID)
            .first()
        else {
            throw HouseError.id
        }
        var floors = Array(house.firstFloor...house.lastFloor)
        switch sort {
        case .down:
            floors.sort { $0 > $1 }
        case .up:
            floors.sort { $0 < $1 }
        }
        return floors
    }
    
    func aparts(on floor: Int, in houseID: House.IDValue) async throws -> [Int] {
        guard let house = try await House.query(on: app.db)
            .filter(\.$id == houseID)
            .first()
        else {
            throw HouseError.id
        }
        let apartPerFloor = Int(house.apartPerFloor)
        let firstFloor = Int(house.firstFloor)
        let firstApart = Int(house.firstApart)
        
        let firstApartOnFloor = apartPerFloor * (floor - firstFloor) + firstApart
        let lastApartOnFloor = firstApartOnFloor + (apartPerFloor - 1)
        
        let aparts = Array(firstApartOnFloor...lastApartOnFloor)
        return aparts
    }
}
