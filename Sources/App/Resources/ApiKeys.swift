//
//  ApiKeys.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Foundation

struct ApiKeys: Codable {
    let telegramApiKey: String
    
    static func decode() -> ApiKeys? {
        guard
            let bundleIdentifier = Bundle.module.bundleIdentifier,
            let bundle = Bundle(identifier: bundleIdentifier),
            let url = bundle.url(forResource: "config", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return .init(telegramApiKey: "") }
        let decoder = JSONDecoder()
        if let result = try? decoder.decode(ApiKeys.self, from: data) {
            return result
        } else {
            return nil// .init(telegramApiKey: "XXXXXXXXXX:YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY")
        }
    }
}


