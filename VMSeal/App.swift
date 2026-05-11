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
    var NewVM: Modal
    
    init(NewVM: Modal) {
        self.NewVM = NewVM
    }
}

@main
struct VMSeal: App {
    @State var supervisor: Supervisor = Supervisor()
    @State private var installer: VM.Installer = VM.Installer()
    
    @State private var hadError: Bool = false
    @State private var errorMessage: String = ""
    
    @State var modal = ModalManager(
        NewVM: Modal()
    )
    
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
                supervisor: $supervisor,
                error: reportError,
                addNewVM: modal.NewVM.show,
            )
            .sheet(isPresented: $modal.NewVM.displayed) {
                Wizard.NewVM(didCancel: modal.NewVM.hide) { name, description, specs in
                    modal.NewVM.hide()
                    
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
