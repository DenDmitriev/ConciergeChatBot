//
//  NeighborBotHandlers.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Vapor
import TelegramVaporBot

final class NeighborBotHandlers: BotHandler {
    
    static let residentCache = Cache<Resident.IDValue, Resident>()
    static let houseCache = Cache<Resident.IDValue, House.NewHouse>()
    
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandNeighborHandler(app: app, connection: connection)
        await commandSearchNeighborByApartHandler(app: app, connection: connection)
        await commandSearchNeighborByCarHandler(app: app, connection: connection)
        await commandSearchNeighborUpstairsHandler(app: app, connection: connection)
        await commandSearchNeighborDownstairsHandler(app: app, connection: connection)
    }
    
    private static func commandNeighborHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: DefaultBotHandlers.Method.neighbor.pattern) { update, bot in
            guard update.callbackQuery?.message?.chat.type == .private else { return }
            guard let user = update.callbackQuery?.from else { return }
            
            let buttons = try await buildButtons(userId: user.id, app: app)
            if buttons.isEmpty {
                let text = Dialog.emptyUser
                let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text)
                try await connection.bot.sendMessage(params: params)
            } else {
                let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
                let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: "Выберите способ поиска соседа", replyMarkup: .inlineKeyboardMarkup(keyboard))
                try await connection.bot.sendMessage(params: params)
            }
        })
    }
    
    private static func commandSearchNeighborByApartHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: Method.apartment.pattern) { update, bot in
            guard update.callbackQuery?.message?.chat.type == .private else { return }
            guard let user = update.callbackQuery?.from else { return }
            
            let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: "Отправьте мне номер квартиры")
            try await bot.sendMessage(params: params)
            
            let handlerName = UUID().uuidString
            let handler = createInputHandler(name: handlerName, for: user.id) { value in
                guard
                    let number = value.parseToInt(),
                    number.isApart
                else {
                    let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: ResidentError.format.localizedDescription)
                    try await bot.sendMessage(params: params)
                    return
                }
                
                let apart = Int16(downcast: number)
                
                try await answerSearchNeighborByApartHandler(userId: user.id, apart: apart, app: app, bot: bot)
                
                await removeHandler(connection: connection, name: handlerName)
            }
            
            await connection.dispatcher.add(handler)
        })
    }
    
    private static func commandSearchNeighborByCarHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: Method.car.pattern) { update, bot in
            guard update.callbackQuery?.message?.chat.type == .private else { return }
            guard let user = update.callbackQuery?.from else { return }
            
            let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: "Отправьте мне номер автомобиля в формате *а123ве78*", parseMode: .markdownV2)
            try await bot.sendMessage(params: params)
            
            let handlerName = UUID().uuidString
            let handler = createInputHandler(name: handlerName, for: user.id) { carNumber in
                guard
                    carNumber.isCarNumber
                else {
                    let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: CarError.format.localizedDescription)
                    try await bot.sendMessage(params: params)
                    return
                }
                
                try await answerSearchNeighborByCarHandler(userId: user.id, carNumber: carNumber, app: app, bot: bot)
                
                await removeHandler(connection: connection, name: handlerName)
            }
            
            await connection.dispatcher.add(handler)
        })
    }
    
    private static func commandSearchNeighborUpstairsHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: Method.upstairs.pattern) { update, bot in
            guard update.callbackQuery?.message?.chat.type == .private else { return }
            guard let user = update.callbackQuery?.from else { return }
            
            try await answerSearchNeighborHandler(userId: user.id, type: .upstairs, app: app, bot: bot)
        })
    }
    
    private static func commandSearchNeighborDownstairsHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: Method.downstairs.pattern) { update, bot in
            guard update.callbackQuery?.message?.chat.type == .private else { return }
            guard let user = update.callbackQuery?.from else { return }
            
            try await answerSearchNeighborHandler(userId: user.id, type: .downstairs, app: app, bot: bot)
        })
    }
    
    static private func answerSearchNeighborByApartHandler(userId: Int64, apart: Int16, app: Vapor.Application, bot: TGBot) async throws {
        let result = try await DatabaseService.getNeighborResidents(from: apart, userId: userId, app: app)
        switch result {
        case .success(let residents):
            let text = "🏢 В квартире \(apart) проживают 👫\n"
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
            try await bot.sendMessage(params: params)
            try await residents.asyncForEach { resident in
                var text = resident.name
                if let username = resident.username {
                    text += " @" + username
                }
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            }
        case .failure(let failure):
            switch failure {
            case .empty:
                let text = failure.localizedDescription
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            default:
                var text = Dialog.cantGetList
                text += "Ошибка: " + failure.localizedDescription
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            }
        }
    }
    
    static private func answerSearchNeighborByCarHandler(userId: Int64, carNumber: String, app: Vapor.Application, bot: TGBot) async throws {
        let result = try await DatabaseService.getNeighborResident(carNumber: carNumber, userId: userId, app: app)
        switch result {
        case .success(let (resident, house)):
            var text = "🚘 Водитель автомобиля \(carNumber)\n"
            text += "👤 " + resident.name
            if let username = resident.username {
                text += " @" + username
            }
            text += "\n🏢 Из чата \(house.name)"
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
            try await bot.sendMessage(params: params)
        case .failure(let failure):
            switch failure {
            case .empty:
                let text = failure.localizedDescription
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            default:
                var text = Dialog.cantGetList
                text += "Ошибка: " + failure.localizedDescription
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            }
        }
    }
    
    static private func answerSearchNeighborHandler(userId: Int64, type: NeighborType, app: Vapor.Application, bot: TGBot) async throws {
        let result = try await DatabaseService.getNeighborResidents(userId: userId, type: type, app: app)
        switch result {
        case .success(let residents):
            let text = "🏢 Соседи \(type.symbol) \(type.text) 👫\n"
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
            try await bot.sendMessage(params: params)
            
            try await residents.asyncForEach { resident in
                var text = "\(resident.name)"
                if let username = resident.username {
                    text += " @" + username
                }
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            }
        case .failure(let failure):
            switch failure {
            case .empty:
                let text = failure.localizedDescription
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            default:
                var text = Dialog.cantGetList
                text += "Ошибка: " + failure.localizedDescription
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
                try await bot.sendMessage(params: params)
            }
        }
    }
    
    static private func buildButtons(userId: Int64, app: Vapor.Application) async throws -> [[TGInlineKeyboardButton]] {
        var buttons = [[TGInlineKeyboardButton]]()
        try await Method.allCases.asyncForEach { method in
            if let searchNeighborButton = try await searchNeighborButton(userId: userId, method: method, app: app) {
                buttons.append([searchNeighborButton])
            }
        }
        return buttons
    }
    
    static func searchNeighborButton(userId: Int64, method: Method, app: Vapor.Application) async throws -> TGInlineKeyboardButton? {
        let residentResult = try await DatabaseService.getResident(for: userId, app: app)
        switch residentResult {
        case .success(let resident):
            let chatId = resident.$house.id
            let callbackData = method.pattern
            guard var urlComponents = URLComponents(string: callbackData) else { return nil }
            let queryItem = URLQueryItem(name: method.query(.chatId), value: String(chatId))
            urlComponents.queryItems = [queryItem]
            guard let url = urlComponents.url else { return nil }
            
            return .init(text: method.text, callbackData: url.absoluteString)
        case .failure:
            return nil
        }
    }
}

extension NeighborBotHandlers {
    enum Method: RawRepresentable, CaseIterable {
        case apartment
        case downstairs
        case upstairs
        case car
        
        enum Query {
            case chatId
        }
        
        func query(_ query: Query) -> String {
            switch query {
            case .chatId:
                return "chatId"
            }
        }
        
        var rawValue: RawValue {
            switch self {
            case .car:
                return "car"
            case .apartment:
                return "apartment"
            case .downstairs:
                return "downstairs"
            case .upstairs:
                return "upstairs"
            }
        }
        
        var pattern: String {
            return self.rawValue
        }
        
        var command: String {
            return "/" + self.rawValue
        }
        
        var text: String {
            switch self {
            case .car:
                return "🔎🚘 Сосед по авто"
            case .apartment:
                return "🔎🏢 Сосед из квартиры"
            case .downstairs:
                return "⬇️ Сосед снизу"
            case .upstairs:
                return "⬆️ Сосед сверху"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}
