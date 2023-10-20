//
//  DefaultBotHandlers.swift
//  
//
//  Created by Denis Dmitriev on 13.10.2023.
//

import Vapor
import TelegramVaporBot

final class DefaultBotHandlers: BotHandler {
    
    static let residentCache = Cache<Resident.IDValue, Resident>()
    static let houseCache = Cache<Resident.IDValue, House.NewHouse>()

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandConciergeHandler(app: app, connection: connection)
        await commandConciergePublicHandler(app: app, connection: connection)
    }
    
    /// Handler for Command /concierge in private
    private static func commandConciergeHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/concierge"]) { update, bot in
            guard update.message?.chat.type == .private else { return }
            guard let userId = update.message?.from?.id else {
                try await update.message?.reply(text: "Sorry, your user id not found", bot: bot)
                return
            }
            let params: TGSendMessageParams
            let buttons = try await buildButtons(for: .resident(chatId: nil, userId: userId), app: app)
            if buttons.isEmpty {
                let text = Dialog.emptyUser
                params = .init(chatId: .chat(userId), text: text)
            } else {
                let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
                params = .init(chatId: .chat(userId),
                               text: Dialog.defaultQuestion,
                               replyMarkup: .inlineKeyboardMarkup(keyboard))
            }
            
            try await connection.bot.sendMessage(params: params)
        })
    }
    
    /// Handler for Command /concierge in public
    private static func commandConciergePublicHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/concierge@ConciergeChatBot"]) { update, bot in
            guard
                let chatId = update.message?.chat.id,
                update.message?.chat.type == .group
            else { return }
            guard let userId = update.message?.from?.id else {
                try await update.message?.reply(text: "Sorry, your user id not found", bot: bot)
                return
            }
            let paramsPublic: TGSendMessageParams = .init(chatId: .chat(chatId),
                                                          text: "Отвечу в приватном чате.",
                                                          disableNotification: true)
            try await connection.bot.sendMessage(params: paramsPublic)
            
            let administrators = try await connection.bot.getChatAdministrators(params: TGGetChatAdministratorsParams(chatId: TGChatId.chat(chatId)))
            let isAdministrator = administrators.map { $0.user.id }.contains(userId)
            
            let buttons: [[TGInlineKeyboardButton]]
            if isAdministrator {
                buttons = try await buildButtons(for: .admin(chatId: chatId, userId: userId), app: app)
            } else {
                buttons = try await buildButtons(for: .resident(chatId: chatId, userId: userId), app: app)
            }
            
            let params: TGSendMessageParams
            if buttons.isEmpty {
                let text = Dialog.emptyUser
                params = .init(chatId: .chat(userId), text: text)
            } else {
                let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
                params = .init(chatId: .chat(userId),
                               text: Dialog.defaultQuestion,
                               replyMarkup: .inlineKeyboardMarkup(keyboard))
            }
            
            try await connection.bot.sendMessage(params: params)
        })
    }
}

extension DefaultBotHandlers {
    enum ChatType {
        case admin(chatId: Int64?, userId: Int64)
        case resident(chatId: Int64?, userId: Int64)
    }
    
    static func buildButtons(for chat: ChatType, app: Vapor.Application) async throws -> [[TGInlineKeyboardButton]] {
        var buttons = [[TGInlineKeyboardButton]]()
        switch chat {
        case .admin(chatId: let chatId, userId: let userId):
            guard let chatId = chatId else { fallthrough }
            if try await isHouseExist(chatId: chatId, app: app) {
                if let adminButton = button(chatId: chatId, method: .admin) {
                    buttons.append([adminButton])
                }
            } else {
                if let registrationButton = button(chatId: chatId, method: .registration) {
                    buttons.append([registrationButton])
                }
            }
            fallthrough
        case .resident(chatId: let chatId, userId: let userId):
            if try await isResident(userId: userId, app: app) {
                let methods: [Method] = [.account, .neighbor, .parking]
                methods.forEach { method in
                    if let button = button(method: method) {
                        buttons.append([button])
                    }
                }
            } else {
                guard let chatId = chatId else { fallthrough }
                if try await isHouseExist(chatId: chatId, app: app) {
                    if let button = button(chatId: chatId, method: .sign) {
                        buttons.append([button])
                    }
                }
            }
            fallthrough
        default:
            return buttons
        }
    }
    
    static private func isHouseExist(chatId: Int64, app: Vapor.Application) async throws -> Bool {
        try await DatabaseService.isExistHouse(chatId: chatId, app: app)
    }
    
    static private func isResident(userId: Int64, app: Vapor.Application) async throws -> Bool {
        try await DatabaseService.isExistResident(userId: userId, app: app)
    }
    
    static func button(chatId: Int64? = nil, method: Method) -> TGInlineKeyboardButton? {
        let callbackData = method.pattern
        guard var urlComponents = URLComponents(string: callbackData) else { return nil }
        if let chatId {
            let queryItem = URLQueryItem(name: method.query(.chatId), value: String(chatId))
            urlComponents.queryItems = [queryItem]
        }
        guard let url = urlComponents.url else { return nil }
        let button: TGInlineKeyboardButton = .init(text: method.text, callbackData: url.absoluteString)
        
        return button
    }
}

extension DefaultBotHandlers {
    enum Method: RawRepresentable {
        case registration
        case sign
        case parking
        case neighbor
        case account
        case admin
        
        var rawValue: String {
            switch self {
            case .admin:
                return "admin"
            case .registration:
                return "registration"
            case .sign:
                return "sign"
            case .parking:
                return "parking"
            case .neighbor:
                return "neighbor"
            case .account:
                return "account"
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
            case .registration:
                return "🏢💬 Зарегистрировать домовой чат"
            case .sign:
                return "📓👫 Записаться в журнале жильцов"
            case .account:
                return "🙋‍♂️ Я"
            case .neighbor:
                return "👫🏢 Соседи"
            case .parking:
                return "🅿️ Парковка"
            case .admin:
                return "🧑‍💼 Администратор"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}
