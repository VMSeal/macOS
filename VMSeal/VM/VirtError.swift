//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  VirtError.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-19.
//

import Virtualization

enum VirtConfigError: Error {
    case invalidConfig(message: String)
    case invalidDisk(message: String)
    case other(message: String)
}

enum VirtStartupError: Error {
    case cannotStart
    case other(message: String)
}

enum VirtShutdownError: Error {
    case cannotStop
    case other(message: String)
}
