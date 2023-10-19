//
//  SignResidentsBotHandlers.swift
//  
//
//  Created by Denis Dmitriev on 16.10.2023.
//

import Vapor
import TelegramVaporBot

final class SignResidentsBotHandlers: BotHandler {
    
    static let residentCache = Cache<Int64 /* userId */, Resident.NewResident>()
    
    // MARK: - Dialog
    
    static var state = Cache<Int64 /* userId */, DialogState>()
    
    enum DialogState {
        case ready
        case waitApprovePersonalData
        case waitFloor
        case waitApart
        case waitApprove
    }
    
    static private func onNext(for userId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot) async throws {
        let dialogState = state[userId] ?? .ready
        switch dialogState {
        case .ready:
            print("ready")
            return
        case .waitApprovePersonalData:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await agreementOfPersonalDataHandler(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitFloor
        case .waitFloor:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await commandFloorHandler(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitApart
        case .waitApart:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await commandApartHandler(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .waitApprove
        case .waitApprove:
            guard let userId = update.callbackQuery?.from.id else { return }
            try await isRightRequest(app: app, connection: connection, update: update, bot: bot, userId: userId)
            state[userId] = .ready
        }
    }
    
    // MARK: - Handlers
    // MARK: Controll handlers
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        try await commandHandler(app: app, connection: connection)
    }
    
    // MARK: Handlers requests
    
    private static func commandHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        let handler = TGCallbackQueryHandler(pattern: DefaultBotHandlers.Method.sign.pattern) { update, bot in
            guard
                let user = update.callbackQuery?.from,
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: DefaultBotHandlers.Method.sign.query(.chatId))
            else { return }
            
            let newResident = Resident.NewResident(id: userId, name: user.firstName, username: user.username, house: chatId)
            residentCache.insert(newResident, forKey: userId)
            
            state[userId] = .waitApprovePersonalData
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func agreementOfPersonalDataHandler(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        guard let chatId = residentCache.value(forKey: userId)?.house else { return }
        let publicChat = try await connection.bot.getChat(params: .init(chatId: .chat(chatId)))
        guard let title = publicChat.title else { return }
        
        let rawText = AgreementForTheStorageOfPersonalData.getText() ?? ""
        let personalText = rawText.replacingOccurrences(of: "CHAT_NAME", with: title)
        try await connection.bot.sendMessage(params: .init(chatId: .chat(userId), text: personalText))
        try await agreementOfPersonalDataButtons(connection: connection, userId: userId)
        
        let handlerName = UUID().uuidString
        let handler = TGCallbackQueryHandler(name: handlerName, pattern: Method.storagePersonalData.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let value = getString(url, query: Method.storagePersonalData.query),
                let approve = value == "true" ? true : false
//                let chatId = residentCache.value(forKey: userId)?.house
            else { return }
            
            guard approve else {
                let text = "Извините, без согласия я не могу собирать данные."
                try await connection.bot.sendMessage(params: .init(chatId: .chat(userId), text: text))
                
                await removeHandler(connection: connection, name: handlerName)
                
                return
            }
            
            await removeHandler(connection: connection, name: handlerName)
            
            let paramsStart: TGSendMessageParams = .init(chatId: .chat(userId), text: "Новая запись для чата - \(title).")
            try await connection.bot.sendMessage(params: paramsStart)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func agreementOfPersonalDataButtons(connection: TGConnectionPrtcl, userId: Int64) async throws {
        let answers = [true, false]
        var buttons: [[TGInlineKeyboardButton]] = []
        let callbackData = Method.storagePersonalData.command
        answers.forEach { answer in
            let answerString = answer ? "Даю согласие" : "Не даю согласие"
            guard var urlComponents = URLComponents(string: callbackData) else { return }
            let queryItem = URLQueryItem(name: Method.storagePersonalData.query, value: answer.description)
            urlComponents.queryItems = [queryItem]
            guard let url = urlComponents.url else { return }
            buttons.append([.init(text: answerString, callbackData: url.absoluteString)])
        }
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                text: Method.storagePersonalData.text,
                                                replyMarkup: .inlineKeyboardMarkup(keyboard))
        
        try await connection.bot.sendMessage(params: params)
    }

    
    private static func floorsButtons(app: Vapor.Application, connection: TGConnectionPrtcl, userId: Int64) async throws {
        guard let newResident = residentCache.value(forKey: userId) else { throw ResidentError.id }
        let houseManager = HouseManager(app: app)
        let floors = try await houseManager.floors(in: newResident.house)
        
        var buttons: [[TGInlineKeyboardButton]] = []
        let callbackData = Method.floor.command
        floors.forEach { floor in
            guard var urlComponents = URLComponents(string: callbackData) else { return }
            let floorString = "\(floor)"
            let queryItem = URLQueryItem(name: Method.floor.query, value: floorString)
            urlComponents.queryItems = [queryItem]
            guard let url = urlComponents.url else { return }
            buttons.append([.init(text: "Этаж \(floorString)", callbackData: url.absoluteString)])
        }
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                text: Method.floor.text,
                                                replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await connection.bot.sendMessage(params: params)
    }
    
    private static func commandFloorHandler(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        
        try await floorsButtons(app: app, connection: connection, userId: userId)
        
        let handlerName = UUID().uuidString
        let handler = TGCallbackQueryHandler(name: handlerName, pattern: Method.floor.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let floor: Int = getNumber(url, query: Method.floor.query),
                var newResident = residentCache.value(forKey: userId)
            else { return }
            
            newResident.floor = floor
            residentCache.insert(newResident, forKey: userId)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func apartButtons(app: Vapor.Application, connection: TGConnectionPrtcl, userId: Int64) async throws {
        guard
            let newResident = residentCache.value(forKey: userId),
            let floor = newResident.floor
        else { throw ResidentError.id }
        
        let houseManager = HouseManager(app: app)
        let aparts = try await houseManager.aparts(on: Int(floor), in: newResident.house)
        var buttons: [[TGInlineKeyboardButton]] = []
        let callbackData = Method.apart.command
        aparts.forEach { apart in
            guard var urlComponents = URLComponents(string: callbackData) else { return }
            let apartString = "\(apart)"
            let queryItem = URLQueryItem(name: Method.apart.query, value: apartString)
            urlComponents.queryItems = [queryItem]
            guard let url = urlComponents.url else { return }
            buttons.append([.init(text: "Квартира \(apartString)", callbackData: url.absoluteString)])
        }
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                text: Method.apart.text,
                                                replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await connection.bot.sendMessage(params: params)
    }
    
    private static func commandApartHandler(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        
        try await apartButtons(app: app, connection: connection, userId: userId)
        
        let handlerName = UUID().uuidString
        let handler = TGCallbackQueryHandler(name: handlerName, pattern: Method.apart.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let apart: Int = getNumber(url, query: Method.apart.query),
                var newResident = residentCache.value(forKey: userId)
            else { return }
            
            newResident.apart = apart
            residentCache.insert(newResident, forKey: userId)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func isRightButtons(app: Vapor.Application, connection: TGConnectionPrtcl, userId: Int64, newResident: Resident.NewResident) async throws {
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
        let text = Method.isRight.text + "\n" + newResident.description()
        let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                text: text,
                                                replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await connection.bot.sendMessage(params: params)
    }
    
    private static func isRightRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, userId: Int64) async throws {
        guard
            let newResident = residentCache.value(forKey: userId)
        else { throw ResidentError.id }
        
        try await isRightButtons(app: app, connection: connection, userId: userId, newResident: newResident)
        
        let handlerName = UUID().uuidString
        
        let handler = TGCallbackQueryHandler(name: handlerName, pattern: Method.isRight.pattern) { update, bot in
            guard
                let userId = update.callbackQuery?.from.id,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let value = getString(url, query: Method.isRight.query)
            else {
                try await update.callbackQuery?.message?.reply(text: ResidentError.some(function: #function).localizedDescription, bot: bot)
                return
            }
            
            let isRight = value == "Да" ? true : false
            
            if isRight {
                let result = try await saveResident(userId: userId, app: app)
                switch result {
                case .success(let success):
                    let house = try await success.$house.get(on: app.db)
                    let name = house.name
                    var text = "Житель успешно записан в журнал для чата \(name).\n"
                    text += "Теперь можете меня вызывать отсюда по команде \n/concierge"
                    try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(Int64(userId)), text: text))
                    clearCache(userId: userId)
                case .failure(let failure):
                    let text = failure.localizedDescription
                    try await connection.bot.sendMessage(params: .init(chatId: TGChatId.chat(Int64(userId)), text: text))
                }
                
            } else {
                state[userId] = .waitFloor
            }
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNext(for: userId, app: app, connection: connection, update: update, bot: bot)
        }
        
        await connection.dispatcher.add(handler)
    }
    
    static private func clearCache(userId: Int64) {
        residentCache.removeValue(forKey: userId)
    }
}

// MARK: - Commands
extension SignResidentsBotHandlers {
    enum Method: RawRepresentable {
        case storagePersonalData
        case floor
        case apart
        case isRight
        
        var rawValue: String {
            switch self {
            case .floor:
                return "floor"
            case .apart:
                return "apart"
            case .isRight:
                return "isRight"
            case .storagePersonalData:
                return "storagePersonalData"
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
            case .floor:
                return "Выберите ваш этаж"
            case .apart:
                return "Выберите вашу квартиру"
            case .isRight:
                return "Запись верна?"
            case .storagePersonalData:
                return "Согласие на обработку персональных данных для бота @ConciergeChatBot в Telegram"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}

// MARK: - Data base methods
extension SignResidentsBotHandlers {
    static private func saveResident(userId: Int64, app: Vapor.Application) async throws -> Result<Resident, ResidentError> {
        guard
            let newResident = residentCache.value(forKey: Int64(userId)),
            let resident = newResident.build()
        else { return .failure(.id) }
        
        if try await DatabaseService.isExistResident(userId: userId, app: app) {
            return try await DatabaseService.updateResident(for: userId, resident: resident, app: app)
        } else {
            return try await DatabaseService.createResident(for: userId, resident: resident, app: app)
        }
    }
}

