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
    let personalDataAgreement: String
    
    enum CodingKeys: String, CodingKey {
        case personalDataAgreement = "PERSONAL_DATA_AGREEMENT"
    }
    
    static func parse() -> Info? {
        guard let url = Bundle.module.url(forResource: "info", withExtension: "plist") else { return nil }
        let data = try! Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        guard let result = try? decoder.decode(Info.self, from: data) else { return nil }
        return result
    }
}
