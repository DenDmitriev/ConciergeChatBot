//
//  PrivateBotHandlers.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Vapor
import TelegramVaporBot

final class PrivateBotHandlers: BotHandler {
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandAccountHandler(app: app, connection: connection)
        await commandLookHandler(app: app, connection: connection)
        await commandCheckOutHandler(app: app, connection: connection)
    }
    
    private static func commandAccountHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCallbackQueryHandler(pattern: DefaultBotHandlers.Method.account.pattern) { update, bot in
            guard let user = update.callbackQuery?.from else { return }
            
            let buttons = buildButtons()
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let text = "Управление вашими записями в журнале"
            
            let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text, replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func commandLookHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCallbackQueryHandler(pattern: Method.look.pattern) { update, bot in
            guard let user = update.callbackQuery?.from else { return }
            
            let text: String = try await residentDescription(user: user, app: app)
            
            let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text)
            try await bot.sendMessage(params: params)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func commandCheckOutHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCallbackQueryHandler(pattern: Method.checkOut.pattern) { update, bot in
            guard let user = update.callbackQuery?.from else { return }
            
            var text: String = ""
            let resultCheckOut = try await DatabaseService.removeResident(by: user.id, app: app)
            switch resultCheckOut {
            case .success(let resident):
                text += "\(resident.name) успешно выписан."
            case .failure(let failure):
                text += failure.localizedDescription
            }
            
            let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text)
            try await bot.sendMessage(params: params)
        }
        await connection.dispatcher.add(handler)
    }
    
    static func residentDescription(user: TGUser, app: Vapor.Application) async throws -> String {
        var description: String = ""
        let result = try await DatabaseService.getResident(for: user.id, app: app)
        switch result {
        case .success(let resident):
            let houseResult = try await DatabaseService.getChatHouse(for: resident.$house.id, app: app)
            switch houseResult {
            case .success(let house):
                description += house.name + "." + "\n"
            case .failure(let failure):
                description += failure.localizedDescription + "\n"
            }
            
            description += resident.description()
            
            let carsResult = try await DatabaseService.getCars(userId: user.id, app: app)
            switch carsResult {
            case .success(let cars):
                if cars.isEmpty {
                    description += "Автомобилей нет." + "\n"
                } else {
                    let carsString = cars
                        .map { $0.description() + "\n" }
                        .reduce("", { $0 + $1 })
                    description += "Гараж: " + carsString + "\n"
                }
            case .failure(let failure):
                description += failure.localizedDescription + "\n"
            }
            
        case .failure(let failure):
            description += failure.localizedDescription + "\n"
        }
        
        return description
    }
    
    // MARK: - Buttons
    static func buildButtons() -> [[TGInlineKeyboardButton]] {
        var buttons = [[TGInlineKeyboardButton]]()
        let methods = Method.allCases
        methods.forEach { method in
            if let button = button(method: method) {
                buttons.append([button])
            }
        }
        return buttons
    }
    
    static func button(method: Method) -> TGInlineKeyboardButton? {
        let callbackData = method.pattern
        guard let url = URL(string: callbackData) else { return nil }
        let button: TGInlineKeyboardButton = .init(text: method.text, callbackData: url.absoluteString)
        
        return button
    }
    
    static func checkOutButton(chatId: Int64?, userId: Int64, app: Vapor.Application) async throws -> TGInlineKeyboardButton? {
        let callbackData = Method.checkOut.pattern
        guard let url = URL(string: callbackData) else { return nil }
        let button: TGInlineKeyboardButton = .init(text: Method.checkOut.text, callbackData: url.absoluteString)
        
        if let chatId {
            let houseResult = try await DatabaseService.getChatHouse(for: chatId, app: app)
            switch houseResult {
            case .success(let house):
                let residentResult = try await DatabaseService.getResident(for: userId, app: app)
                switch residentResult {
                case .success(let resident):
                    if resident.$house.id == house.id {
                        return button
                    } else {
                        return nil
                    }
                case .failure:
                    return nil
                }
            case .failure:
                return nil
            }
        } else {
            let houseResult = try await DatabaseService.getHouse(for: userId, app: app)
            switch houseResult {
            case .success(let house):
                let residentResult = try await DatabaseService.getResident(for: userId, app: app)
                switch residentResult {
                case .success(let resident):
                    if resident.$house.id == house.id {
                        return button
                    } else {
                        return nil
                    }
                case .failure:
                    return nil
                }
            case .failure:
                return nil
            }
        }
    }
}

extension PrivateBotHandlers {
    enum Method: RawRepresentable, CaseIterable {
        case look
        case checkOut
        
        var rawValue: String {
            switch self {
            case .look:
                return "look"
            case .checkOut:
                return "checkOut"
            }
        }
        
        enum Query {
            case chatId
        }
        
        func query(_ query: Query) -> String {
            switch query {
            case .chatId:
                return "chatId"
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
            case .look:
                return "📓 Моя запись"
            case .checkOut:
                return "🧳 Выписаться"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}
