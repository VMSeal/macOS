//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  String.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-30.
//

import Foundation



extension String {
    struct Base64 {
        let string: String
        
        var encoded: String {
            String(data: Data(base64Encoded: self.string)!, encoding: .utf8)!
        }
        
        var decoded: String {
            Data(self.string.utf8).base64EncodedString()
        }
    }
    
    var base64: Base64 {
        Base64(string: self)
    }
}
