//
//  AdminBotHandlers.swift
//  
//
//  Created by Denis Dmitriev on 18.10.2023.
//

import Vapor
import TelegramVaporBot

final class AdminBotHandlers: BotHandler {
    
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandAdminHandler(app: app, connection: connection)
    }
    
    private static func commandAdminHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCallbackQueryHandler(pattern: DefaultBotHandlers.Method.admin.pattern) { update, bot in
            guard
                let user = update.callbackQuery?.from,
                let data = update.callbackQuery?.data,
                let url = URL(string: data),
                let chatId: Int64 = getNumber(url, query: DefaultBotHandlers.Method.admin.query(.chatId))
            else { return }
            
            let buttons = buildButtons(chatId: chatId)
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(user.id),
                           text: "Какой у вас вопрос?",
                           replyMarkup: .inlineKeyboardMarkup(keyboard))
            
            try await bot.sendMessage(params: params)
        }
        await connection.dispatcher.add(handler)
    }
    
    static func buildButtons(chatId: Int64) -> [[TGInlineKeyboardButton]] {
        var buttons = [[TGInlineKeyboardButton]] ()
        Method.allCases.forEach { method in
            if let button = button(chatId: chatId, method: method) {
                buttons.append([button])
            }
        }
        return buttons
    }
    
    static func button(chatId: Int64, method: Method) -> TGInlineKeyboardButton? {
        let callbackData = method.pattern
        var urlComponents = URLComponents(string: callbackData)
        let queryItem = URLQueryItem(name: Method.editHouse.query(.chatId), value: String(chatId))
        urlComponents?.queryItems = [queryItem]
        guard let url = urlComponents?.url else { return nil }
//        guard var url = URL(string: callbackData) else { return nil }
//        let queryItem = URLQueryItem(name: Method.editHouse.query(.chatId), value: String(chatId))
//        url.append(queryItems: [queryItem])
        let button: TGInlineKeyboardButton = .init(text: method.text, callbackData: url.absoluteString)
        
        return button
    }
    
}

extension AdminBotHandlers {
    enum Method: RawRepresentable, CaseIterable {
        case editHouse
        
        var rawValue: String {
            switch self {
            case .editHouse:
                return "editHouse"
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
            case .editHouse:
                return "Изменить данные чата дома"
            }
        }
        
        init?(rawValue: String) {
            return nil
        }
    }
}
