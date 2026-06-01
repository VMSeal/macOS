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
@MainActor
class ModalManager {
    var newVM: Modal
    var editVM: Modal
    
    init(newVM: Modal, editVM: Modal) {
        self.newVM = newVM
        self.editVM = editVM
    }
}

@main
struct VMSeal: App {
    @State var supervisor: Supervisor = Supervisor()
    @State private var installer: VM.Installer = VM.Installer()
    
    @State private var hadError: Bool = false
    @State private var errorMessage: String = ""
    
    @State var modal = ModalManager(
        newVM: Modal(),
        editVM: Modal()
    )
    
    @State var selection: Set<VM.ID> = []
    
    @State var editing: VM? = nil
    @State var renaming: VM? = nil
    
    var selectedVMs: [VM] {
        return supervisor.vms.filter { box in
            selection.contains(box.id)
        }
    }
    
    var selectedVM: VM? {
        return selectedVMs.count == 1 ? selectedVMs.first : nil
    }
    
    init() {
        // Restores saved VMs from disk
        supervisor.restore()
        
        // We have to set this property in the initialiser,
        // otherwise Swift gets angry.
        installer.supervisor = supervisor
    }
    
    var body: some Scene {
        WindowGroup {
            Dashboard(
                error: reportError,
                addVM: modal.newVM.show,
                renameVM: { newName in
                    if let vm = supervisor.currentVM {
                        renaming = nil
                        try? supervisor.rename(vm, to: newName)
                    }
                },
                startVM: {
                    try? await supervisor.currentVM?.start()
                },
                stopVM: {
                    supervisor.currentVM?.stop()
                },
                editVM: { memory, vCPUs in
                    if let vm = supervisor.currentVM {
                        supervisor.edit(vm, memory: memory, vCPUs: vCPUs)
                    }
                },
                deleteVM: { vm in
                    let _ = supervisor.delete(vm)
                },
                setCurrentVM: { vm in
                    supervisor.currentVM = vm
                },
                selection: $selection,
                selectedVMs: selectedVMs,
                selectedVM: selectedVM,
                renaming: $renaming,
                editing: $editing,
                noVMs: supervisor.vms.isEmpty,
                vms: $supervisor.vms
            )
            .sheet(isPresented: $modal.newVM.displayed) {
                Wizard.NewVM(didCancel: modal.newVM.hide) { name, description, specs in
                    modal.newVM.hide()
                    Task {
                        do {
                            try await installer.install(
                                name: name,
                                specs: specs
                            )
                        } catch let e as VM.InstallerDownloadError {
                            reportError(e.message)
                        } catch let e as VM.InstallerVerificationError {
                            reportError(e.message)
                        } catch let e as VM.InstallerConfigurationError {
                            reportError(e.message)
                        } catch VM.InstallerConfigurationCheckError.failed(let reason) {
                            reportError("Failed pre-install check: \(reason)")
                        } catch let e {
                            reportError(e.localizedDescription)
                        }
                    }
                }
            }
            .sheet(isPresented: $installer.active) {
                InstallProgress(
                    progress: $installer.progress,
                    status: $installer.status
                )
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
                        supervisor.edit(editing!, memory: submitted.memory, vCPUs: submitted.vCPUs)
                        editing = nil
                    },
                    vm: $editing
                )
            }
            .alert(errorMessage, isPresented: $hadError) {
                Button("OK") {
                    hadError = false
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
    
    static func quit() -> Void {
        NSApplication.shared.terminate(self)
    }
    
    func reportError(_ message: String?) -> Void {
        self.errorMessage = message ?? "Something went wrong!"
        self.hadError = true
    }
}
