//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  ContentView.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-21.
//

import Foundation
import SwiftUI
import Virtualization

enum DashboardToolbarItemKey {
    case new
    case start
    case stop
    case inspector
}

struct ContentView: View {
    @Environment(ViewModel.self) private var viewModel
    
    @ViewBuilder var inspector: some View {
        if let config = self.viewModel.selectedVM?.config {
            InspectorRow(
                key: "Disk:",
                value: ByteUnit.HumanReadable.from(config.diskSizeInBytes, in: .GiB)
            )
            
            Divider()
            
            InspectorRow(
                key: "RAM:",
                value: ByteUnit.HumanReadable.from(config.memoryInBytes, in: .GiB)
            )
            
            Divider()
            
            InspectorRow(
                key: "vCPUs:",
                value: String(config.vCPUs)
            )
        }
    }
    
    @ContentBuilder var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Start", systemImage: "play.fill", action: {
                self.viewModel.didClickToolbarButton(.start)
            })
            .disabled(self.viewModel.shouldToolbarButtonBeDisabled(.start))
            
            Button("Stop", systemImage: "stop.fill", action: {
                self.viewModel.didClickToolbarButton(.stop)
            })
            .disabled(self.viewModel.shouldToolbarButtonBeDisabled(.stop))
            
            Spacer()
                .frame(width: 40)
            
            Button("Inspector", systemImage: "sidebar.right", action: {
                self.viewModel.didClickToolbarButton(.inspector)
            })
            .disabled(self.viewModel.shouldToolbarButtonBeDisabled(.inspector))
        }
        
        ToolbarItemGroup(placement: .navigation) {
            Button("New VM", systemImage: "plus", action: {
                self.viewModel.didClickToolbarButton(.new)
            })
            .disabled(self.viewModel.shouldToolbarButtonBeDisabled(.new))
        }
    }
    
    var sidebar: some View {
        @Bindable var viewModel = self.viewModel
        
        return List($viewModel.vms, id: \.id, selection: $viewModel.selection) { $vm in
            Label(vm.config.name, systemImage: "shippingbox")
                .contextMenu {
                    Button("Edit", systemImage: "square.and.pencil") {
                        viewModel.openSheet(.editVM)
                        viewModel.vmBeingEdited = vm
                    }
                    .disabled(vm.state != .stopped || self.viewModel.selection.count > 1)
                    
                    Button("Delete", systemImage: "minus", role: .destructive) {
                        viewModel.deleteAllSelected()
                    }
                }
        }
    }
    
    var viewport: some View {
        ZStack {
            if self.viewModel.selectedVM?.state == .stopped {
                Color(red: 0, green: 0, blue: 0)
                
                HStack {
                    Image(systemName: "pause.circle")
                    
                    Spacer()
                        .frame(width: 10)
                    
                    Text("Stopped")
                        .bold()
                }
                .font(.largeTitle)
                .foregroundStyle(.white)
            } else {
                ViewportRepresentable(currentVM: self.viewModel.selectedVM!)
                    .id(self.viewModel.selectedVM!.id)
            }
        }
    }
    
    @ViewBuilder var detail: some View {
        if self.viewModel.selection.count > 1 {
            VStack {
                Text("\(self.viewModel.selection.count) VMs selected")
                    .font(.title2.bold())
            }
        } else if self.viewModel.selectedVM != nil {
            self.viewport
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var body: some View {
        @Bindable var viewModel = self.viewModel
        
        NavigationSplitView {
            self.sidebar
        } detail: {
            self.detail
                .inspector(isPresented: $viewModel.shouldShowInspector) {
                    InspectorView(title: "Hardware") {
                        self.inspector
                    }
                }
        }
        .navigationSplitViewColumnWidth(120)
        .navigationSplitViewStyle(.prominentDetail)
        .navigationTitle("Dashboard")
        .toolbar {
            self.toolbar
        }
        .sheet(item: $viewModel.presentedSheet) { sheet in
            switch sheet {
            case .newVM:
                NewVMSheetView {
                    self.viewModel.closeSheet()
                } didSubmit: { submission in
                    self.viewModel.didSubmitNewVMSheet(submission: submission)
                }
            case .editVM:
                if let previousConfig = self.viewModel.currentEditConfig {
                    EditVMSheetView(previous: previousConfig) {
                        self.viewModel.closeSheet()
                    } didSubmit: { submission in
                        self.viewModel.didSubmitEditVMSheet(self.viewModel.vmBeingEdited!, submission: submission)
                    }
                }
            case .installer:
                InstallerView(
                    progress: .constant(self.viewModel.installer!.progress),
                    status: .constant(self.viewModel.installer!.status!)
                )
            }
        }
    }
}

extension ContentView {
    @Observable
    class ViewModel {
        private var supervisor: Supervisor
        private let reportError: @Sendable (_: String?) -> Void
        
        private(set) var installer: Installer?
        
        var shouldShowInspector: Bool
        var vmBeingRenamed: VM?
        var vmBeingEdited: VM?
        
        var selection: Set<VM.ID>
        
        init(
            supervisor: Supervisor,
            reportError: @escaping @Sendable (_: String?) -> Void,
        ) {
            self.supervisor = supervisor
            self.reportError = reportError
            
            self.shouldShowInspector = false
            self.vmBeingRenamed = nil
            self.vmBeingEdited = nil
            self.selection = []
        }
        
        var currentEditConfig: EditVMSheetView.EditSubmission? {
            if let vm = self.vmBeingEdited {
                return EditVMSheetView.EditSubmission(
                    vCPUs: vm.config.vCPUs,
                    memory: vm.config.memoryInBytes,
                    newName: vm.config.name
                )
            }
            
            return nil
        }
        
        var presentedSheet: Sheet? {
            get {
                SharedAppState.shared.presentedSheet
            }
            set {}
        }
        
        var selectedVMs: [VM] {
            self.vms.filter { vm in
                self.selection.contains(vm.id)
            }
        }
        
        var selectedVM: VM? {
            guard self.selection.count == 1 else {
                return nil
            }
            
            return self.selectedVMs.first
        }
        
        var vms: [VM] {
            get {
                self.supervisor.allSupervised
            }
            set {}
        }
        
        func openSheet(_ sheet: Sheet) {
            SharedAppState.shared.presentedSheet = sheet
        }
        
        func closeSheet() {
            SharedAppState.shared.presentedSheet = nil
        }
        
        func didSubmitNewVMSheet(submission: VM.Configuration) {
            self.closeSheet()
            
            let installer = Installer(
                source: Constant.source,
                config: submission
            )
            
            self.installer = installer
            
            Task {
                do {
                    SharedAppState.shared.presentedSheet = .installer
                    
                    defer {
                        self.closeSheet()
                        self.installer = nil
                    }
                    
                    let vm = try await installer.start()
                    self.supervisor.supervise(machine: vm)
                } catch let e {
                    self.closeSheet()
                    self.installer = nil
                    
                    self.reportError("Installation failed: \(e.localizedDescription)")
                }
            }
        }
        
        func didSubmitEditVMSheet(_ machine: VM, submission: EditVMSheetView.EditSubmission) {
            self.closeSheet()
            
            // TODO: error handling
            guard self.supervisor.supervises(machine: machine) else {
                return
            }
            
            var newConfig = machine.config
            newConfig.memoryInBytes = submission.memory
            newConfig.vCPUs = submission.vCPUs
            newConfig.name = submission.newName
            
            // TODO: error handling
            try? self.supervisor.edit(machine: machine, toConfig: newConfig)
            self.vmBeingEdited = nil
        }
        
        func didClickToolbarButton(_ item: DashboardToolbarItemKey) {
            switch item {
            case .new:
                SharedAppState.shared.presentedSheet = .newVM
            case .start:
                guard self.selection.count == 1 else {
                    return
                }
                
                Task {
                    do {
                        try await self.selectedVM!._start()
                        //try await self.supervisor.start(machine: self.selectedVM!)
                    } catch let e {
                        self.reportError(e.localizedDescription)
                    }
                }
            case .stop:
                guard self.selection.count == 1 else {
                    return
                }
                
                Task {
                    do {
                        try await self.supervisor.stop(machine: self.selectedVM!)
                    } catch let e {
                        self.reportError(e.localizedDescription)
                    }
                }
            case .inspector:
                self.shouldShowInspector = !self.shouldShowInspector
            }
        }
        
        func shouldToolbarButtonBeDisabled(_ item: DashboardToolbarItemKey) -> Bool {
            switch item {
            case .new:
                return false
            case .start:
                return self.selectedVM == nil || self.selectedVM?.state == .running
            case .stop:
                return self.selectedVM == nil || self.selectedVM?.state == .stopped
            case .inspector:
                return self.selectedVM == nil
            }
        }
        
        func deleteAllSelected() {
            // TODO: error handling
            Task {
                for id in self.selection {
                    do {
                        guard let vm = self.vms.first(where: { $0.id == id }) else {
                            continue
                        }
                        
                        try await self.supervisor.delete(machine: vm)
                    } catch let e {
                        self.reportError(e.localizedDescription)
                    }
                }
                
                // Unselect all VMs, otherwise the dashboard thinks that
                // the deleted VMs are still selected.
                self.selection.removeAll()
            }
        }
    }
}
