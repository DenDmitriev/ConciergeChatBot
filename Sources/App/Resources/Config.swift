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
    let personalDataAgreement: String
    
    enum CodingKeys: String, CodingKey {
        case telegramApiKey = "TELEGRAM_API_KEY"
        case personalDataAgreement = "PERSONAL_DATA_AGREEMENT"
    }
    
    static func parseConfig() -> Config? {
//        var url: URL? = nil
//        switch RUNTYPE {
//        case .dev:
//            url = Bundle.module.url(forResource: "config", withExtension: "plist")
//        case .prod:
//            url = URL(string: "/code/Sources/App/Resources/config.plist")
//        }
//        guard let url else { return nil }
        guard let url = Bundle.module.url(forResource: "config", withExtension: "plist") else { return nil }
        print("🍭 config.plist", url.absoluteString)
        let data = try! Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        guard let result = try? decoder.decode(Config.self, from: data) else { return nil }
        return result
    }
}
