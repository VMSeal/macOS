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
    static func atob(text: String) -> String? {
        guard let data = Data(base64Encoded: text) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func btoa() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}
