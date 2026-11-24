//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  InspectorView.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-22.
//

import SwiftUI

struct InspectorRow: View {
    let key: String
    let value: String
    
    var body: some View {
        GridRow {
            Text(key)
            Spacer()
                .frame(maxWidth: .infinity, maxHeight: 2)
            Text(value)
        }
        .font(.system(size: 16))
        .padding(2)
        .gridColumnAlignment(.leading)
    }
}

struct InspectorView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(self.title)
                    .font(.title2)
                    .bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
            
            GroupBox {
                Grid {
                    self.content
                }
            }
        }
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
