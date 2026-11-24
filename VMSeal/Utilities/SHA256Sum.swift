//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  SHA256Sum.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-10.
//

import Foundation
import CryptoKit

struct SHA256Sum: Hashable, Codable {
    
    private static func digestOf(_ data: Data, chunkSize: Int = 8192) -> String {
        var hasher = SHA256()
        
        // Iterate over the data, stepping by the chunkSize given,
        // and updating the hasher in-between.
        for offset in stride(from: 0, to: data.count, by: chunkSize) {
            let end = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]
            
            hasher.update(data: chunk)
        }
        
        // We want a string representation of the digest.
        let hexDigest = hasher.finalize().compactMap {
            unsafe String(format: "%02x", $0)
        }.joined()
        
        return hexDigest
    }
    
    let digest: String
    
    init(_ digest: String) {
        self.digest = digest
    }
    
    init(from string: String) {
        self.digest = SHA256Sum.digestOf(
            Data(string.utf8)
        )
    }
    
    init(from data: Data) {
        self.digest = SHA256Sum.digestOf(data)
    }
    
    func matches(_ comparator: SHA256Sum) -> Bool {
        return self.digest == comparator.digest
    }
    
    func matches(_ comparator: String) -> Bool {
        return self.digest == comparator
    }
}
