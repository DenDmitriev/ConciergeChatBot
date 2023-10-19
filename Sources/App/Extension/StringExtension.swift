//
//  File.swift
//  
//
//  Created by Denis Dmitriev on 17.10.2023.
//

import Foundation

extension String {
    var isCarNumber: Bool {
        let okayChars = Set("0123456789авекмнорстух")
        if !self.filter({ value in
//            !okayChars.contains($0.lowercased())
            !okayChars.contains(value)
        }).isEmpty {
            return false
        }
        if !(7...9 ~= self.count) {
            return false
        }
        return true
    }
    
    func parseToInt() -> Int? {
        return (self as NSString).integerValue
    }
}
