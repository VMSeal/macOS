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
    @Binding var supervisor: Supervisor
    
    let error: @Sendable (String?) -> Void
    let addNewVM: () -> Void
    
    @State var selection: Set<VM.ID> = []
    
    @State var renaming: VM? = nil
    @State var editing: VM? = nil
    
    /** When set to `.Info`, it will show the info inspector to the right *besides* the VM. */
    @State var view: DashView = .VM
    
    @State private var toolbarButtonState = Toolbar.DisabledButton(
        start: .disabled,
        stop: .disabled,
        info: .disabled
    )
    
    var selectedVMs: [VM] {
        return supervisor.vms.filter { box in
            selection.contains(box.id)
        }
    }
    
    var selectedVM: VM? {
        return selectedVMs.count == 1 ? selectedVMs.first : nil
    }
    
    var body: some View {
        toolbarButtonState.start = selectedVM == nil ? .disabled : .enabled
        toolbarButtonState.stop = selectedVM == nil ? .disabled : .enabled
        toolbarButtonState.info = selectedVM == nil ? .disabled : .enabled
        
        supervisor.currentVM = selectedVM
        
        let viewingInfo = Binding<Bool>(
            get: {
                self.view == .Info
            },
            set: { newValue in
                self.view = newValue ? .Info : .VM
            }
        )
        
        return NavigationSplitView {
            self.list
        } detail: {
            self.detail
                .inspector(isPresented: viewingInfo) {
                    self.info
                }
        }
        .navigationSplitViewColumnWidth(120)
        .navigationSplitViewStyle(.prominentDetail)
        .navigationTitle("Dashboard")
        .toolbar {
            let toolbar = Dashboard.Toolbar(
                start: {
                    do {
                        guard let vm = selectedVM else {
                            throw NSError()
                        }
                        
                        Task {
                            try await vm.start()
                        }
                    } catch {
                        self.error("Failed to start the selected VM!")
                    }
                },
                stop: {
                    do {
                        guard let vm = selectedVM else {
                            throw NSError()
                        }
                        
                        vm.stop()
                    } catch {
                        self.error("Failed to stop the selected VM!")
                    }
                },
                disabled: self.$toolbarButtonState,
                selection: self.$selection,
                view: self.$view
            )
            
            toolbar.toolbar
        }
        .sheet(
            isPresented: Binding<Bool>(
                get: {
                    editing != nil
                },
                set: { _ in
                    editing = nil
                }
            )
        ) {
            Wizard.EditVM(
                didCancel: {
                    editing = nil
                },
                didSubmit: { submitted in
                    edit(vm: editing!, memory: submitted.memory, vCPUs: submitted.vCPUs)
                },
                vm: $editing
            )
        }
    }
}

extension Dashboard {
    func rename(vm: VM, name: String?) -> Void {
        self.renaming = nil // Don't show any dialogue or similar
        
        if name != nil {
            do {
                try vm.rename(to: name!)
            } catch let e {
                self.error(e.localizedDescription)
            }
        }
    }
    
    func edit(vm: VM, memory: Double, vCPUs: Double) -> Void {
        self.editing = nil
        
        vm.memory = memory
        vm.vCPUs = vCPUs
        
        try? vm.configure() // required for changes to take effect
        vm.backup()
    }
}

extension Dashboard {
    enum DashView {
        case VM
        case Info
    }
}
