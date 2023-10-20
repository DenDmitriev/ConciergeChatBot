//
//  Info.swift
//  
//
//  Created by Denis Dmitriev on 20.10.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Info: Codable {
    var personalDataAgreement: String
    
    enum CodingKeys: String, CodingKey {
        case personalDataAgreement = "PERSONAL_DATA_AGREEMENT"
    }
    
    static func parse(for chatName: String, botName: String) -> Info? {
        guard let url = Bundle.module.url(forResource: "info", withExtension: "plist") else { return nil }
        let data = try! Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        guard var result = try? decoder.decode(Info.self, from: data) else { return nil }
        result.personalDataAgreement = result.personalDataAgreement.replacingOccurrences(of: "CHAT_NAME", with: chatName)
        result.personalDataAgreement = result.personalDataAgreement.replacingOccurrences(of: "TGBOT_NAME", with: botName)
        return result
    }
}
