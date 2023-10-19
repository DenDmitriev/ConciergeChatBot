//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 18.10.2023.
//

import Foundation

struct AgreementForTheStorageOfPersonalData {
    static func getText() -> String? {
        guard
            let bundleIdentifier = Bundle.module.bundleIdentifier,
            let bundle = Bundle(identifier: bundleIdentifier),
            let url = bundle.url(forResource: "agreementForTheStorageOfPersonalData", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return text
    }
}
