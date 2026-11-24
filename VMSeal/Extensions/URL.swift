//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  URL.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-18.
//

import Foundation

extension URL {
    struct LocalURL {
        let url: URL
        
        /**
         * Get the URL of the macOS app's home directory.
         * **IMPORTANT:** If the app is *not* sandboxed, then it will return the user's home directory.
         */
        static var app: URL {
            FileManager.default.homeDirectoryForCurrentUser
        }
        
        static var iso: URL {
            self.app.appendingPathComponent("ISOs")
        }
        
        func exists() -> Bool {
            FileManager.default.fileExists(atPath: url.path())
        }
        
        func mkdir() throws -> Void {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        func remove() throws -> Void {
            try FileManager.default.removeItem(at: url)
        }
        
        func move(to destination: URL) throws -> Void {
            try FileManager.default.moveItem(at: self.url, to: destination)
        }
        
        func checksum(binary: Bool = false) throws -> SHA256Sum {
            var contents: Data
            
            if binary {
                contents = try Data(contentsOf: self.url)
            } else {
                contents = Data(
                    try self.readString(encoding: .utf8)
                        .utf8
                )
            }
            
            return SHA256Sum(from: contents)
        }
        
        func readString(encoding: String.Encoding = .utf8) throws -> String {
            try String(contentsOf: url, encoding: encoding)
            
        }
        
        func writeString(
            content: String = "",
            encoding: String.Encoding = .utf8
        ) throws -> Void {
            try content.write(
                toFile: self.url.path(),
                atomically: false,
                encoding: encoding
            )
        }
    }
    
    var local: LocalURL {
        LocalURL(url: self)
    }
}
