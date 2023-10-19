//
//  DatabaseService.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Fluent
import Vapor

final class DatabaseService {
    
    static func saveHouse(userId: Int64, newHouse: House.NewHouse, app: Vapor.Application) async throws -> Result<House, TransactionError> {
        if let existHouse = try await House.find(newHouse.id, on: app.db) {
            return .failure(.alreadyExist(name: existHouse.name))
        } else {
            if let house = newHouse.build() {
                do {
                    try await house.create(on: app.db)
                    return .success(house)
                } catch let error {
                    return .failure(.unknown(description: error.localizedDescription))
                }
            } else {
                return .failure(.cantSave)
            }
        }
    }
    
    static func updateHouse(userId: Int64, newHouse: House.NewHouse, app: Vapor.Application) async throws -> Result<House, TransactionError> {
        guard
            let existHouse = try await House.find(newHouse.id, on: app.db)
        else { return .failure(.notFound) }
        
        if let house = newHouse.build() {
            do {
                existHouse.firstFloor = house.firstFloor
                existHouse.lastFloor = house.lastFloor
                existHouse.apartPerFloor = house.apartPerFloor
                existHouse.firstApart = house.firstApart
                try await existHouse.update(on: app.db)
                return .success(house)
            } catch let error {
                return .failure(.unknown(description: error.localizedDescription))
            }
        } else {
            return .failure(.cantSave)
        }
    }
    
    static func isExistHouse(chatId: House.IDValue, app: Vapor.Application) async throws -> Bool {
        if let _ = try await House.find(chatId, on: app.db) {
            return true
        } else {
            return false
        }
    }
    
    static func getHouse(for residentId: Resident.IDValue, app: Vapor.Application) async throws -> Result<House, HouseError> {
        guard let resident = try await Resident.find(residentId, on: app.db) else {
            return .failure(.id)
        }
        let house = try await resident.$house.get(on: app.db)
        return .success(house)
    }
    
    static func getChatHouse(for chatId: House.IDValue, app: Vapor.Application) async throws -> Result<House, HouseError> {
        guard let house = try await House.find(chatId, on: app.db) else {
            return .failure(.id)
        }
        return .success(house)
    }
    
    static func isExistResident(userId: Resident.IDValue, app: Vapor.Application) async throws -> Bool {
        if let _ = try await Resident.find(userId, on: app.db) {
            return true
        } else {
            return false
        }
    }
    
    static func getResident(for userId: Resident.IDValue, app: Vapor.Application) async throws -> Result<Resident, ResidentError> {
        guard let resident = try await Resident.find(userId, on: app.db) else {
            return .failure(.id)
        }
        return .success(resident)
    }
    
    static func createResident(for userId: Resident.IDValue, resident: Resident, app: Vapor.Application) async throws -> Result<Resident, ResidentError> {
        do {
            try await resident.create(on: app.db)
            return .success(resident)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func updateResident(for userId: Resident.IDValue, resident: Resident, app: Vapor.Application) async throws -> Result<Resident, ResidentError> {
        guard let existResident = try await Resident.find(userId, on: app.db) else { return .failure(.id) }
        existResident.apart = resident.apart
        existResident.floor = resident.floor
        existResident.name = resident.name
        existResident.username = resident.username
        do {
            try await existResident.update(on: app.db)
            return .success(existResident)
        } catch let error {
            return .failure(ResidentError.some(function: error.localizedDescription))
        }
    }
    
    static func removeResident(by userId: Resident.IDValue, app: Vapor.Application) async throws -> Result<Resident, ResidentError> {
        guard let resident = try await Resident.find(userId, on: app.db) else { return .failure(.id) }
        do {
            try await resident.delete(on: app.db)
            return .success(resident)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func getNeighborResidents(from apart: Int16, userId: Resident.IDValue, app: Vapor.Application) async throws -> Result<[Resident], ResidentError> {
        guard let resident = try await Resident.find(userId, on: app.db) else { return .failure(.id) }
        do {
            let residents = try await Resident.query(on: app.db)
                .filter(\.$house.$id == resident.$house.id)
                .filter(\.$apart == apart)
                .sort(\.$name)
                .all()
            if residents.isEmpty {
                return .failure(.empty)
            }
            return .success(residents)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func getNeighborResident(carNumber: String, userId: Resident.IDValue, app: Vapor.Application) async throws -> Result<(Resident, House), ResidentError> {
        guard let _ = try await Resident.find(userId, on: app.db) else { return .failure(.id) }
        do {
            guard
                let car = try await Car.query(on: app.db)
                    .filter(\.$number == carNumber.lowercased())
                    .all()
                    .first
            else { return .failure(.some(function: "Автомобиля с номером \(carNumber) нет в журнале")) }
            
            let resident = try await car.$resident.get(on: app.db)
            let house = try await car.$house.get(on: app.db)
            
            return .success((resident, house))
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func getNeighborResidents(userId: Resident.IDValue, type: NeighborType, app: Vapor.Application) async throws -> Result<[Resident], ResidentError> {
        guard let resident = try await Resident.find(userId, on: app.db) else { return .failure(.id) }
        
        let house = try await resident.$house.get(on: app.db)
        
        let searchApart: Int16
        switch type {
        case .upstairs:
            searchApart = resident.apart + Int16(house.apartPerFloor)
        case .downstairs:
            searchApart = resident.apart - Int16(house.apartPerFloor)
        }
        
        do {
            let residents = try await Resident.query(on: app.db)
                .filter(\.$house.$id == house.id ?? 0)
                .filter(\.$apart == searchApart)
                .sort(\.$name)
                .all()
            if residents.isEmpty {
                return .failure(.empty)
            }
            return .success(residents)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func addAuto(chatId: Int64, userId: Int64, app: Vapor.Application, number: String) async throws -> Result<Car, CarError> {
        return .failure(.empty)
    }
    
    static func addBlockedAuto(chatId: Int64, userId: Int64, app: Vapor.Application, number: String) async throws -> Result<BlockedCar, CarError> {
        let houseResult = try await DatabaseService.getHouse(for: userId, app: app)
        switch houseResult {
        case .success(let house):
            guard let chatId = house.id else { return .failure(.some(function: "Не удалось найти ваш дом.")) }
            let blockedCar = BlockedCar(driver: userId, number: number, houseId: chatId)
            do {
                try await blockedCar.create(on: app.db)
                return .success(blockedCar)
            } catch let error {
                return .failure(.some(function: error.localizedDescription))
            }
        case .failure:
            return .failure(.some(function: "Не удалось найти ваш дом."))
        }
    }
    
    static func getBlockedAutoList(chatId: House.IDValue, app: Vapor.Application) async throws -> Result<[BlockedCar], CarError> {
        try await cleanBlockedAutoList(app: app)
        let expiredDate = Calendar.current.date(byAdding: .hour, value: -12, to: Date.now)
        let blockedCars = try await BlockedCar.query(on: app.db)
            .filter(\.$house.$id == chatId)
            .filter(\.$createdAt > expiredDate)
            .sort(\.$createdAt)
            .all()
        if blockedCars.isEmpty {
            return .failure(.empty)
        } else {
            return .success(blockedCars)
        }
    }
    
    // Delete all objects with an expiration date of 12 hours
    static private func cleanBlockedAutoList(app: Vapor.Application) async throws {
        let blockedList = try await BlockedCar.query(on: app.db).all()
        let dateNow = Date.now
        blockedList.forEach { blockedCar in
            guard
                let expiredDate = Calendar.current.date(byAdding: .hour, value: -12, to: dateNow),
                let createdAtDate = blockedCar.createdAt
            else { return }
            if createdAtDate <= expiredDate {
                Task {
                    try await blockedCar.delete(on: app.db)
                }
            }
        }
    }
    
    static func isExistCar(number: String, app: Vapor.Application) async throws -> Bool {
        let cars = try await Car.query(on: app.db)
            .filter(\.$number == number)
            .all()
        if cars.isEmpty {
            return false
        } else {
            return true
        }
    }
    
    static func createCar(newCar: Car.NewCar, app: Vapor.Application) async throws -> Result<Car, CarError> {
        guard let car = newCar.build() else { return .failure(.noValue) }
        do {
            try await car.create(on: app.db)
            return .success(car)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func updateCar(newCar: Car.NewCar, app: Vapor.Application) async throws -> Result<Car, CarError> {
        guard let car = newCar.build() else { return .failure(.noValue) }
        do {
            try await car.update(on: app.db)
            return .success(car)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
    
    static func getCars(userId: Resident.IDValue, app: Vapor.Application) async throws -> Result<[Car], CarError> {
        guard let resident = try await Resident.find(userId, on: app.db) else {
            return .failure(.id)
        }
        let cars = try await resident.$cars.get(on: app.db)
        return .success(cars)
    }
    
    static func deleteCar(id: UUID, app: Vapor.Application) async throws -> Result<Car, CarError> {
        guard let car = try await Car.find(id, on: app.db) else { return .failure(.id) }
        do {
            try await car.delete(on: app.db)
            return .success(car)
        } catch let error {
            return .failure(.some(function: error.localizedDescription))
        }
    }
}
