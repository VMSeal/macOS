//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Constants.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-21.
//

import Foundation

enum Sheet: String, Identifiable {
    case newVM
    case editVM
    case installer
    
    var id: String {
        self.rawValue
    }
}

struct ActionState {
    var active: Bool
    var target: VM?
}

enum Constant {
    static var source: Installer.Source = Installer.Source(
        iso: URL(string: "https://images.vmseal.org/vmseal.iso")!,
        checksum: SHA256Sum("e445ceec9cd8bcd5b85f61b6b9acba8c35ec1975322fef92dee4378f4200340c"),
        filename: "vmseal.iso"
    )
}
