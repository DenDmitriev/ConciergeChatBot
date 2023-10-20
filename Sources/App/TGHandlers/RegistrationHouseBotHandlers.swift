//
//  RegistrationHouseBotHandlers.swift
//  
//
//  Created by Denis Dmitriev on 16.10.2023.
//

import Vapor
import TelegramVaporBot

final class RegistrationHouseBotHandlers: BotHandler {
    
    static let houseCache = Cache<Resident.IDValue, House.NewHouse>()
    
    // MARK: - Dialog
    
    static var state = Cache<Int64 /* userId */, DialogState>()
    
    enum DialogState {
        case ready
        case waitLowFloor
        case waitLastFloor
        case waitApartPerFloor
        case waitFirstApart
        case waitApprove
        case waitUpdate
    }
    
    static private func onNext(for userId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot) async throws {
        let dialogState = state[userId] ?? .ready
        switch dialogState {
        case .ready:
            return
        case .waitLowFloor:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await lowFloorRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitLastFloor
        case .waitLastFloor:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await lastFloorRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitApartPerFloor
        case .waitApartPerFloor:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await apartPerFloorRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitFirstApart
        case .waitFirstApart:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await firstApartRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitApprove
        case .waitApprove:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await isRightRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            if state[userId] == .waitApprove {
                state[userId] = .ready
            }
        case .waitUpdate:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await updateHouseRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .ready
        }
    }
    
    // MARK: - Handlers
    // MARK: Controll handlers
    
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        try await commandRegistrationHandler(app: app, connection: connection)
        try await commandEditHandler(app: app, connection: connection)
    }
    
    // MARK: Handlers requests
    
    private static func commandRegistrationHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        let handler = TGCallbackQueryHandler(pattern: DefaultBotHandlers.Method.registration.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: DefaultBotHandlers.Method.registration.query(.chatId))
            else { return }
            
            let publicChat = try await connection.bot.getChat(params: .init(chatId: TGChatId.chat(chatId)))
            
            guard let title = publicChat.title else { return }
            let paramsStart: TGSendMessageParams = .init(chatId: .chat(userId),
                                                         text: "Начинаю регистрацию для чата - \(title).")
            try await connection.bot.sendMessage(params: paramsStart)
            
            createHouse(userId: userId, chatId: chatId, title: title)
            
            state[userId] = .waitLowFloor
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func commandEditHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        let handler = TGCallbackQueryHandler(pattern: AdminBotHandlers.Method.editHouse.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: DefaultBotHandlers.Method.registration.query(.chatId))
            else { return }
            
            let publicChat = try await connection.bot.getChat(params: .init(chatId: TGChatId.chat(chatId)))
            
            guard let title = publicChat.title else { return }
            let paramsStart: TGSendMessageParams = .init(chatId: .chat(userId),
                                                         text: "Меняю данные для чата - \(title).")
            try await connection.bot.sendMessage(params: paramsStart)
            
            createHouse(userId: userId, chatId: chatId, title: title)
            
            state[userId] = .waitLowFloor
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func lowFloorRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: Method.lowFloor.text)
        try await bot.sendMessage(params: params)
        
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard
                let lowApart = Int(value)
            else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: HouseError.format.localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            updateHouse(userId: userId, firstFloor: lowApart)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func lastFloorRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: Method.lastFloor.text)
        try await bot.sendMessage(params: params)
        
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard
                let lastFloor = Int(value)
            else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: HouseError.format.localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            updateHouse(userId: userId, lastFloor: lastFloor)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func apartPerFloorRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: Method.apartPerFlor.text)
        try await bot.sendMessage(params: params)
        
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard
                let apartPerFlor = Int(value)
            else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: HouseError.format.localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            updateHouse(userId: userId, apartPerFloor: apartPerFlor)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func firstApartRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: Method.firstApart.text)
        try await bot.sendMessage(params: params)
        
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard
                let firstApart = Int(value)
            else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: HouseError.format.localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            updateHouse(userId: userId, firstApart: firstApart)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func isRightButtons(app: Vapor.Application, connection: TGConnectionPrtcl, userId: Int64, newHouse: House.NewHouse) async throws {
        let callbackData = Method.isRight.pattern
        guard let url = URL(string: callbackData) else { return }
        let answers = ["Да", "Нет"]
        var buttons = [[TGInlineKeyboardButton]]()
        answers.forEach { answer in
            let queryItem = URLQueryItem(name: Method.isRight.query, value: answer)
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = [queryItem]
            let url = urlComponents?.url ?? url
            let button = [TGInlineKeyboardButton(text: answer, callbackData: url.absoluteString)]
            buttons.append(button)
        }
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let text = Method.isRight.text + "\n" + newHouse.description()
        let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                text: text,
                                                replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await connection.bot.sendMessage(params: params)
    }
    
    private static func isRightRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        guard let newHouse = houseCache.value(forKey: userId) else { return }
        try await isRightButtons(app: app, connection: connection, userId: userId, newHouse: newHouse)
        
        let handlerName = UUID().uuidString
        
        let handler = TGCallbackQueryHandler(name: handlerName, pattern: Method.isRight.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let value = getString(url, query: Method.isRight.query)
            else {
                try await update.callbackQuery?.message?.reply(text: HouseError.some(function: #function).localizedDescription, bot: bot)
                return
            }
            
            let isRight = value == "Да" ? true : false
            
            if isRight {
                let result = try await saveHouse(userId: userId, app: app)
                switch result {
                case .success(let success):
                    let text = "Дом для чата - \(success.name) успешно сохранен"
                    try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(userId), text: text))
                case .failure(let failure):
                    let text: String
                    switch failure {
                    case .alreadyExist:
                        text = failure.localizedDescription
                        try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(userId), text: text))
                        try await updateHouseButtons(app: app, connection: connection, userId: userId)
                        state[userId] = .waitUpdate
                    default:
                        text = failure.localizedDescription
                        try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(userId), text: text))
                    }
                }
                
            } else {
                state[userId] = .waitLowFloor
            }
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        
        await connection.dispatcher.add(handler)
    }
    
    private static func updateHouseButtons(app: Vapor.Application, connection: TGConnectionPrtcl, userId: Int64) async throws {
        let callbackData = Method.update.pattern
        guard let url = URL(string: callbackData) else { return }
        let answers = ["Да", "Нет"]
        var buttons = [[TGInlineKeyboardButton]]()
        answers.forEach { answer in
            let queryItem = URLQueryItem(name: Method.update.query, value: answer)
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = [queryItem]
            let url = urlComponents?.url ?? url
            let button = [TGInlineKeyboardButton(text: answer, callbackData: url.absoluteString)]
            buttons.append(button)
        }
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        var text = Method.update.text
        if
            let newHouse = try await getHouse(from: .cache, userId: userId, app: app),
            let existHouse = try await getHouse(from: .database, userId: userId, app: app)
        {
            text += "\n"
            text += "\nСуществующие\n\n"
            text += existHouse.description()
            text += "\n"
            text += "\nна новые\n\n"
            text += newHouse.description()
        }
        
        let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                text: text,
                                                replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await connection.bot.sendMessage(params: params)
    }
    
    private static func updateHouseRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        
        let handlerName = UUID().uuidString
        
        let handler = TGCallbackQueryHandler(name: handlerName, pattern: Method.update.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let value = getString(url, query: Method.update.query)
            else {
                try await update.callbackQuery?.message?.reply(text: HouseError.some(function: #function).localizedDescription, bot: bot)
                return
            }
            
            let isUpdate = value == "Да" ? true : false
            
            if isUpdate {
                let result = try await updateHouse(userId: userId, app: app)
                switch result {
                case .success(let success):
                    let text = "Дом для чата - \(success.name) успешно сохранен"
                    try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(userId), text: text))
                    clearCache(userId: userId)
                case .failure(let failure):
                    switch failure {
                    default:
                        let text = failure.localizedDescription
                        try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(userId), text: text))
                    }
                }
            }
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        
        await connection.dispatcher.add(handler)
    }
}

// MARK: - Commands
extension RegistrationHouseBotHandlers {
    enum Method: RawRepresentable {
        case registration
        case lowFloor
        case lastFloor
        case apartPerFlor
        case firstApart
        case isRight
        case update
        
        var rawValue: String {
            switch self {
            case .registration:
                return "registration"
            case .lowFloor:
                return "lowFloor"
            case .lastFloor:
                return "lastFloor"
            case .apartPerFlor:
                return "apartPerFlor"
            case .firstApart:
                return "firstApart"
            case .isRight:
                return "isRight"
            case .update:
                return "update"
            }
        }
        
        var query: String {
            return self.rawValue
        }
        
        var pattern: String {
            return self.rawValue
        }
        
        var command: String {
            return self.rawValue
        }
        
        var text: String {
            switch self {
            case .registration:
                return "Зарегистрировать домовой чат"
            case .lowFloor:
                return "Отправьте номер этажа где начинаются жилые квартиры"
            case .lastFloor:
                return "Отправьте номер последнего жилого этажа"
            case .apartPerFlor:
                return "Отправьте количество квартир на одном этаже"
            case .firstApart:
                return "Отправьте номер первой квартиры на самом низком жилом этаже"
            case .isRight:
                return "Введённые вами данные верны?"
            case .update:
                return "Обновить данные дома?"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}

// MARK: - Cache methods
extension RegistrationHouseBotHandlers {
    
    static private func createHouse(userId: Int64, chatId: Int64, title: String) {
        let newHouse = House.NewHouse(id: chatId, name: title)
        houseCache.insert(newHouse, forKey: userId)
    }
    
    static private func clearCache(userId: Int64) {
        houseCache.removeValue(forKey: userId)
    }
    
    static private func updateHouse(userId: Int64,
                                    firstFloor: Int? = nil,
                                    lastFloor: Int? = nil,
                                    apartPerFloor: Int? = nil,
                                    firstApart: Int? = nil) {
        guard var newHouse = houseCache.value(forKey: userId) else { return }
        if let firstFloor {
            newHouse.firstFloor = firstFloor
        }
        if let lastFloor {
            newHouse.lastFloor = lastFloor
        }
        if let apartPerFloor {
            newHouse.apartPerFloor = apartPerFloor
        }
        if let firstApart {
            newHouse.firstApart = firstApart
        }
        
        houseCache.insert(newHouse, forKey: userId)
    }
    
    static private func saveHouse(userId: Int64, app: Vapor.Application) async throws -> Result<House, TransactionError> {
        guard
            let newHouse = houseCache.value(forKey: userId)
        else { return .failure(.notFound) }
        
        let result = try await DatabaseService.saveHouse(userId: userId, newHouse: newHouse, app: app)
        return result
    }
    
    static private func updateHouse(userId: Int64, app: Vapor.Application) async throws -> Result<House, TransactionError> {
        guard
            let newHouse = houseCache.value(forKey: userId)
        else { return .failure(.notFound) }
        
        let result = try await DatabaseService.updateHouse(userId: userId, newHouse: newHouse, app: app)
        return result
    }
    
    enum Source {
        case database, cache
    }
    
    static private func getHouse(from: Source, userId: Int64, app: Vapor.Application) async throws -> House? {
        guard let newHouse = houseCache.value(forKey: userId) else { return nil }
        switch from {
        case .database:
            let result = try await DatabaseService.getChatHouse(for: newHouse.id, app: app)
            switch result {
            case .success(let house):
                return house
            case .failure:
                return nil
            }
        case .cache:
            guard
                let buildHouse = newHouse.build()
            else { return nil }
            return buildHouse
        }
    }
}
