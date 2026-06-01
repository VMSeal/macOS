//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Dashboard.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-02-12.
//


import SwiftUI
import Virtualization

struct Dashboard: View {
    enum DashView {
        case VM
        case Info
    }
    
    let error: @Sendable (String?) -> Void
    
    let addVM: () -> Void
    let renameVM: (String) -> Void
    let startVM: () async throws -> Void
    let stopVM: () -> Void
    let editVM: (Double, Double) -> Void
    let deleteVM: (VM) -> Void
    let setCurrentVM: (VM) -> Void
    
    @Binding var selection: Set<VM.ID>
    
    let selectedVMs: [VM]
    let selectedVM: VM?
    
    @Binding var renaming: VM?
    @Binding var editing: VM?
    
    let noVMs: Bool
    @Binding var vms: [VM]
    
    /** When set to `.Info`, it will show the info inspector to the right *besides* the VM. */
    @State var view: DashView = .VM
    
    @State private var toolbarButtonState = Toolbar.DisabledButton(
        start: .disabled,
        stop: .disabled,
        info: .disabled
    )
    
    var body: some View {
        if let vm = selectedVM {
            setCurrentVM(vm)
        }

        // TODO: Move this logic which doesn't belong here
        toolbarButtonState.start = selectedVM == nil ? .disabled : .enabled
        toolbarButtonState.stop = selectedVM == nil ? .disabled : .enabled
        toolbarButtonState.info = selectedVM == nil ? .disabled : .enabled
        
        let viewingInfo = Binding<Bool>(
            get: {
                view == .Info
            },
            set: { newValue in
                view = newValue ? .Info : .VM
            }
        )
        
        return NavigationSplitView {
            list
        } detail: {
            detail
                .inspector(isPresented: viewingInfo) {
                    info
                }
        }
        .navigationSplitViewColumnWidth(120)
        .navigationSplitViewStyle(.prominentDetail)
        .navigationTitle("Dashboard")
        .toolbar {
            let toolbar = Dashboard.Toolbar(
                start: {
                    Task {
                        do {
                            try await startVM()
                        } catch {
                            self.error("Failed to start the selected VM!")
                        }
                    }
                },
                stop: stopVM,
                disabled: self.$toolbarButtonState,
                selection: self.$selection,
                view: self.$view
            )
            
            toolbar.toolbar
        }
    }
}
