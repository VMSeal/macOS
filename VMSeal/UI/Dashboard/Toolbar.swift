//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Toolbar.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-23.
//

import SwiftUI

extension Dashboard {
    struct Toolbar {
        
        enum ButtonState {
            case disabled
            case enabled
        }
        
        @Observable
        class DisabledButton {
            
            var start: ButtonState
            var stop: ButtonState
            var info: ButtonState
            
            init(start: ButtonState, stop: ButtonState, info: ButtonState) {
                self.start = start
                self.stop = stop
                self.info = info
            }
        }
        
        let start: () -> Void
        let stop: () -> Void
        
        let unselectVMs: () -> Void
        
        @Binding var disabled: DisabledButton
        
        @Binding var selection: Set<VM.ID>
        @Binding var view: DashView
        
        @ToolbarContentBuilder var toolbar: some ToolbarContent {
            ToolbarItemGroup(placement: .primaryAction) {
                
                Button("Stop", systemImage: "stop.fill", action: stop)
                    .disabled(disabled.stop == .disabled)
                
                Button("Start", systemImage: "play.fill", action: start)
                    .disabled(disabled.start == .disabled)
                
                Spacer()
                    .frame(width: 40)
                
                Button("Info", systemImage: "sidebar.right") {
                    if self.view == .Info {
                        self.view = .VM
                    } else {
                        self.view = .Info
                    }
                }
            }
            
            ToolbarItemGroup(placement: .navigation) {
                Button("Home", systemImage: "house") {
                    unselectVMs()
                }
            }
        }
    }
}
