//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  App.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-02-12.
//


import Foundation
import SwiftUI
import Virtualization
import AppKit

@Observable
class SharedAppState {
    static let shared = SharedAppState()
    
    var presentedSheet: Sheet?
    
    init() {
        self.presentedSheet = nil
    }
}

@main
struct VMSeal: App {
    enum WindowId: String {
        case mainWindow
    }
    
    static func quit() {
        NSApplication.shared.terminate(self)
    }
    
    @State private var errorMessage: String? = nil
    
    @State private var supervisor = Supervisor()
    
    func reportError(_ message: String?) -> Void {
        self.errorMessage = message ?? "Something went wrong!"
    }
    
    @CommandsBuilder var menubar: some Commands {
        CommandGroup(before: .newItem) {
            Button("New VM...", action: { SharedAppState.shared.presentedSheet = .newVM })
                .keyboardShortcut("N", modifiers: [.command, .shift])
        }
    }
    
    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    var body: some Scene {
        Window("VMSeal", id: WindowId.mainWindow.rawValue) {
            ContentView()
                .onAppear {
                    Task {
                        try? await self.supervisor.restoreAll()
                    }
                }
                .environment(
                    ContentView.ViewModel(
                        supervisor: self.supervisor,
                        reportError: self.reportError
                    )
                )
                .alert(self.errorMessage ?? "", isPresented: .constant(self.errorMessage != nil)) {
                    Button("OK") {
                        self.errorMessage = nil
                    }
                }
        }
        .commands {
            menubar
        }
    
        Settings {
            settings
        }
    }
}
