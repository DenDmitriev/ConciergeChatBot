//
//  Config.swift
//  
//
//  Created by Denis Dmitriev on 14.10.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Config: Codable {
    let telegramApiKey: String
    
    enum CodingKeys: String, CodingKey {
        case telegramApiKey = "TELEGRAM_API_KEY"
    }
    
    static func parse() -> Config? {
        guard let url = Bundle.module.url(forResource: "config", withExtension: "plist") else { return nil }
        let data = try! Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        guard let result = try? decoder.decode(Config.self, from: data) else { return nil }
        return result
    }
}
