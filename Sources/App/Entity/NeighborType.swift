//
//  NeighborType.swift
//  
//
//  Created by Denis Dmitriev on 18.10.2023.
//

import Foundation

enum NeighborType {
    case downstairs, upstairs
    
    var symbol: String {
        switch self {
        case .downstairs:
            return "⬇️"
        case .upstairs:
            return "⬆️"
        }
    }
    
    var text: String {
        switch self {
        case .downstairs:
            return "снизу"
        case .upstairs:
            return "сверху"
        }
    }
}
