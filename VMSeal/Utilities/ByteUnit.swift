//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  ByteUnit.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-24.
//

import Foundation

struct ByteUnit {
    enum Unit: String {
        case KiB
        case MiB
        case GiB
    }
    
    struct HumanReadable {
        static func from(_ bytes: Double, in unit: ByteUnit.Unit) -> String {
            var value = bytes
            
            switch unit {
            case .KiB:
                value = value / 1024
            case .MiB:
                value = value / 1024 / 1024
            case .GiB:
                value = value / 1024 / 1024 / 1024
            }
            
            return "\(value.rounded().formatted(.number)) \(unit)"
        }
    }
}
