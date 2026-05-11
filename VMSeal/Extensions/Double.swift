//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Double.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-03.
//

import Foundation

enum CastableNumber {
    case int (Int)
    case uint64 (UInt64)
}

fileprivate struct Unit {
    static let KiB = 1024
    static let MiB = 1024 * 1024
    static let GiB = 1024 * 1024 * 1024
}

extension Double {
    
    // --- Byte unit conversion ---
    
    var KiB: Self {
        self * Double(Unit.KiB)
    }
    
    var MiB: Self {
        self * Double(Unit.MiB)
    }
    
    var GiB: Self {
        self * Double(Unit.GiB)
    }

    
    
    // --- Methods for safer casting ---
    
    
    // [Side Note]: Not sure how to DRY this section up,
    // either way, it is needed...
    
    var asInt: Int {
        guard let converted = Int(exactly: self.rounded()) else {
            return Int(0)
        }
        
        return converted
    }
    
    var asInt64: Int64 {
        guard let converted = Int64(exactly: self.rounded()) else {
            return Int64(0)
        }
        
        return converted
    }
    
    var asUInt64: UInt64 {
        guard let converted = UInt64(exactly: self.rounded()) else {
            return UInt64(0)
        }
        
        return converted
    }
}
