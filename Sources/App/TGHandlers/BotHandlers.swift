//
//  BotHandler.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Vapor
import TelegramVaporBot

protocol Handler {
    static func removeHandler(connection: TGConnectionPrtcl, name: String) async
    static func createInputHandler(name: String, for userId: Int64, completion: @escaping ((String) async throws -> Void)) -> TGHandlerPrtcl
}

class BotHandler: Handler {
    
    static func removeHandler(connection: TGConnectionPrtcl, name: String) async {
        await connection.dispatcher.handlersGroup.asyncForEach { handlers in
            if let handler = handlers.first(where: { $0.name == name }) {
                await connection.dispatcher.remove(handler, from: nil)
            }
        }
    }
    
    static func createInputHandler(name: String, for userId: Int64, completion: @escaping ((String) async throws -> Void)) -> TGHandlerPrtcl {
        let inputHandler = TGMessageHandler(name: name) { update, bot in
            // Verify user by id
            guard userId == update.message?.from?.id else { return }
            guard let message = update.message?.text else { return }
            
            try await completion(message)
        }
        return inputHandler
    }
    
    static func getNumber<T: Downcastable>(_ url: URL, query: String) -> T? {
        guard
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let valueString = urlComponents.queryItems?.first(where: { $0.name == query })?.value,
            let value = valueString.parseToInt()
        else {
            return nil
        }
        return T(downcast: value)
    }
    
    static func getString(_ url: URL, query: String) -> String? {
        guard
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let valueString = urlComponents.queryItems?.first(where: { $0.name == query })?.value
        else {
            return nil
        }
        return valueString
    }
}
