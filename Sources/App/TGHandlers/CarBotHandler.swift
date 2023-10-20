//
//  CarBotHandler.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Vapor
import TelegramVaporBot

final class CarBotHandler: BotHandler {

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        await commandCarHandler(app: app, connection: connection)
        try await commandBlockedListHandler(app: app, connection: connection)
        await commandAddBlockedAutoHandler(app: app, connection: connection)
        await commandAddResidentAutoHandler(app: app, connection: connection)
    }
    
    // MARK: - Dialog
    
    static var state = Cache<Int64 /* userId */, AddAutoDialogState>()
    static var cacheAuto = Cache<Int64 /* userId */, Car.NewCar>()
    
    enum AddAutoDialogState {
        case ready
        case waitNumber
        case waitModel
    }
    
    static private func onNextAddAuto(for userId: Int64, chatId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot) async throws {
        let dialogState = state[userId] ?? .ready
        switch dialogState {
        case .ready:
            return
        case .waitNumber:
            try await addResidentAutoNumberRequest(chatId: chatId, userId: userId, app: app, connection: connection, update: update, bot: bot)
            state[userId] = .waitModel
        case .waitModel:
            try await addResidentAutoModelRequest(chatId: chatId, userId: userId, app: app, connection: connection, update: update, bot: bot)
            state[userId] = .ready
        }
    }
    
    private static func commandCarHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: DefaultBotHandlers.Method.parking.pattern) { update, bot in
            guard update.callbackQuery?.message?.chat.type == .private else { return }
            guard let user = update.callbackQuery?.from else { return }
            
            let params: TGSendMessageParams
            let buttons = try await buildButtons(userId: user.id, app: app)
            if buttons.isEmpty {
                let text = Dialog.emptyUser
                params = .init(chatId: .chat(user.id), text: text)
            } else {
                let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
                params = .init(chatId: .chat(user.id),
                                                        text: Dialog.defaultQuestion,
                                                        replyMarkup: .inlineKeyboardMarkup(keyboard))
            }
            
            try await connection.bot.sendMessage(params: params)
        })
    }
    
    private static func commandBlockedListHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async throws {
        let handler = TGCallbackQueryHandler(pattern: Method.blocked.pattern) { update, bot in
            guard
                let user = update.callbackQuery?.from,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: Method.blocked.query(.chatId))
            else { return }
            
            let blockedListResult = try await DatabaseService.getBlockedCarList(chatId: chatId, app: app)
            switch blockedListResult {
            case .success(let blockedList):
                let text = Method.blocked.text + "\n"
                let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text)
                try await bot.sendMessage(params: params)
                
                try await blockedList.asyncForEach { blockedCar in
                    let userId = blockedCar.driver
                    let driverUser = try await connection.bot.getChatMember(params: .init(chatId: .chat(chatId), userId: userId))
                    let text = "🙋‍♂️ \(driverUser.user.firstName) @\(driverUser.user.username ?? "")"
                    + " запер 🚘 " + blockedCar.number.uppercased()
                    let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text)
                    try await bot.sendMessage(params: params)
                }
            case .failure:
                let text = Dialog.emptyList
                let params: TGSendMessageParams = .init(chatId: .chat(user.id), text: text)
                try await bot.sendMessage(params: params)
            }
            
            
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func commandAddBlockedAutoHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCallbackQueryHandler(pattern: Method.addBlockedAuto.pattern) { update, bot in
            guard
                let user = update.callbackQuery?.from,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: Method.addBlockedAuto.query(.chatId))
            else { return }
            
            try await addBlockedAutoRequest(app: app, connection: connection, update: update, bot: bot, chatId: chatId, userId: user.id)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func addBlockedAutoRequest(app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot, chatId: Int64, userId: Int64) async throws {
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Отправьте мне номер автомобиля который заперт")
        try await bot.sendMessage(params: params)
        
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard value.isCarNumber else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: CarError.format.localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            let text: String
            let result = try await DatabaseService.addBlockedCar(chatId: chatId, userId: userId, app: app, number: value)
            switch result {
            case .success(let blockedCar):
                text = "Автомобиль 🚘 \(blockedCar.number) успешно добавлен в список запертых на 🅿️ парковке. Если владелец сделает запрос, то получит ваше имя для связи."
            case .failure(let failure):
                text = failure.localizedDescription
            }
            
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text)
            try await bot.sendMessage(params: params)
            
            await removeHandler(connection: connection, name: handlerName)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func commandAddResidentAutoHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCallbackQueryHandler(pattern: Method.addResidentAuto.pattern) { update, bot in
            guard
                let user = update.callbackQuery?.from,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: Method.addBlockedAuto.query(.chatId))
            else { return }
            
            state[user.id] = .waitNumber
            
            try await onNextAddAuto(for: user.id, chatId: chatId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func addResidentAutoNumberRequest(chatId: Int64, userId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot) async throws {
        let paramsDescription: TGSendMessageParams = .init(chatId: .chat(userId), text: Dialog.addResidentAuto)
        try await bot.sendMessage(params: paramsDescription)
        
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Отправьте мне номер своего автомобиля в формате *а123ве78*", parseMode: .markdownV2)
        try await bot.sendMessage(params: params)
        
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard value.isCarNumber else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: CarError.format.localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            let text = "Записываю 🚘 номер *\(value)*"
            let newCar = Car.NewCar(number: value.lowercased(), residentId: userId, houseId: chatId)
            addAutoCache(userId: userId, newCar: newCar)
            
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text, parseMode: .markdownV2)
            try await bot.sendMessage(params: params)
            
            await removeHandler(connection: connection, name: handlerName)
            
            try await onNextAddAuto(for: userId, chatId: chatId, app: app, connection: connection, update: update, bot: bot)
        }
        await connection.dispatcher.add(handler)
    }
    
    private static func addResidentAutoModelRequest(chatId: Int64, userId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl, update: TGUpdate, bot: TGBot) async throws {
        let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Отправьте мне модель своего автомобиля")
        try await bot.sendMessage(params: params)
        
        let length = 16
        let handlerName = UUID().uuidString
        let handler = createInputHandler(name: handlerName, for: userId) { value in
            guard value.count <= length else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: CarError.length(count: length).localizedDescription)
                try await bot.sendMessage(params: params)
                return
            }
            
            guard var newCar = getAutoCache(userId: userId) else { return }
            newCar.model = value
            updateAutoCache(userId: userId, newCar: newCar)
            let text = "Записываю 🚘 модель *\(value)*"
            
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: text, parseMode: .markdownV2)
            try await bot.sendMessage(params: params)
            
            var textResult = ""
            let result = try await saveAuto(userId: userId, app: app)
            switch result {
            case .success(let car):
                textResult += car.description()
                textResult += "\nзаписан в журнал"
            case .failure(let failure):
                textResult += failure.localizedDescription
            }
            
            let paramsResult: TGSendMessageParams = .init(chatId: .chat(userId), text: textResult)
            try await bot.sendMessage(params: paramsResult)
            
            await removeHandler(connection: connection, name: handlerName)
        }
        await connection.dispatcher.add(handler)
    }
    
    // MARK: - Buttons
    
    static private func buildButtons(userId: Int64, app: Vapor.Application) async throws -> [[TGInlineKeyboardButton]] {
        var buttons = [[TGInlineKeyboardButton]]()
        try await Method.allCases.asyncForEach { method in
            if let methodButton = try await methodButton(userId: userId, method: method, app: app) {
                buttons.append([methodButton])
            }
        }
        return buttons
    }
    
    static func methodButton(userId: Int64, method: Method, app: Vapor.Application) async throws -> TGInlineKeyboardButton? {
        let residentResult = try await DatabaseService.getResident(for: userId, app: app)
        switch residentResult {
        case .success(let resident):
            let chatId = resident.$house.id
            
            let callbackData = method.pattern
//            guard var url = URL(string: callbackData) else { return nil }
//            let queryItem = URLQueryItem(name: method.query(.chatId), value: String(chatId))
//            url.append(queryItems: [queryItem])
            
            var urlComponents = URLComponents(string: callbackData)
            let queryItem = URLQueryItem(name: method.query(.chatId), value: String(chatId))
            urlComponents?.queryItems = [queryItem]
            guard let url = urlComponents?.url else { return nil }
            
            return .init(text: method.text, callbackData: url.absoluteString)
        case .failure:
            return nil
        }
    }
}

extension CarBotHandler {
    enum Method: RawRepresentable, CaseIterable {
        case blocked
        case addBlockedAuto
        case addResidentAuto
        
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
            case .blocked:
                return "blocked"
            case .addBlockedAuto:
                return "addBlockedAuto"
            case .addResidentAuto:
                return "addResidentAuto"
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
            case .blocked:
                return "🔒🅿️ Запертые авто сегодня"
            case .addBlockedAuto:
                return "🚙🚘 Добавить запертое авто"
            case .addResidentAuto:
                return "🚘 Добавить мой автомобиль"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}

// MARK: - Add resident auto cache methods
extension CarBotHandler {
    static private func addAutoCache(userId: Int64, newCar: Car.NewCar) {
        cacheAuto.insert(newCar, forKey: userId)
    }
    
    static private func updateAutoCache(userId: Int64, newCar: Car.NewCar) {
        guard var newCacheCar = getAutoCache(userId: userId) else { return }
        newCacheCar.model = newCar.model
        newCacheCar.number = newCar.number
        cacheAuto.insert(newCacheCar, forKey: userId)
    }
    
    static private func getAutoCache(userId: Int64) -> Car.NewCar? {
        cacheAuto.value(forKey: userId)
    }
    
    static private func clearAutoCache(userId: Int64) {
        cacheAuto.removeValue(forKey: userId)
    }
    
    static private func saveAuto(userId: Int64, app: Vapor.Application) async throws -> Result<Car, CarError> {
        guard
            let newCar = getAutoCache(userId: userId),
            let number = newCar.number
        else { return .failure(.noValue) }
        let isExist = try await DatabaseService.isExistCar(number: number, app: app)
        if isExist {
            guard let newCar = getAutoCache(userId: userId) else { return .failure(.id) }
            let result = try await DatabaseService.updateCar(newCar: newCar, app: app)
            return result
        } else {
            guard let newCar = getAutoCache(userId: userId) else { return .failure(.id) }
            let result = try await DatabaseService.createCar(newCar: newCar, app: app)
            return result
        }
    }
}
