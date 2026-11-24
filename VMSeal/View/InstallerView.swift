//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  InstallerView.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-22.
//

import Foundation
import SwiftUI

struct InstallerView: View {
    @Binding var progress: Double
    @Binding var status: Installer.Status
    
    var body: some View {
        VStack {
            if self.progress >= 0 && self.progress < 100 {
                ProgressView(value: self.progress)
                Text(self.status.rawValue)
            } else {
                ProgressView()
            }
        }
        .padding(8)
    }
}
