//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Menubar.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-02-20.
//

import SwiftUI
import Virtualization

extension VMSeal {
    @CommandsBuilder var menubar: some Commands {
        CommandGroup(before: .newItem) {
            Button("New VM...", action: modal.newVM.show)
                .disabled(modal.newVM.displayed)
                .keyboardShortcut("N", modifiers: [.command, .shift])
        }
        
        CommandMenu("VM") {
            let toggled = Binding<Bool>(
                get: { supervisor.currentVM?.cdrom.state == .inserted },
                set: { _ in
                    guard let vm = supervisor.currentVM else {
                        return
                    }
                    
                    do {
                        try vm.cdrom.toggle(vm: vm)
                    } catch let e as LocalizedError {
                        reportError(e.errorDescription)
                    } catch let e {
                        reportError(e.localizedDescription)
                    }
                }
            )
            
            Toggle("Insert CDROM", isOn: toggled)
                .disabled(
                    supervisor.currentVM == nil || supervisor.currentVM?.state != .stopped
                )
        }
    }
}
