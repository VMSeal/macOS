//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Installer.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-26.
//

import SwiftUI

extension VM {
    @Observable
    @MainActor
    class Installer {
        
        private struct CheckResult {
            var reason: String?
            var passed: Bool
        }
        
        /** An array of closures which checks if a VM can be created */
        private let checks: [(String, VM.Specification) -> CheckResult] = [
            { name, _ in
                // Does the VM contain any duplicates? If so, return `true`, else `false`.
                let anyDuplicates = VM.Storage.all.contains { $0 == name }
                
                var result = CheckResult(passed: !anyDuplicates)
                
                if anyDuplicates {
                    result.reason = "A VM with the same name was found!"
                }
                
                return result
            }
        ]
        
        enum Status: String {
            case downloading = "Downloading ISO image..."
            case verifying = "Verifying checksum..."
            case configuring = "Configuring new VM..."
        }
        
        var active: Bool = false
        var status: Status? = nil
        var progress: Double = -1
        
        /** The source the installer will install */
        var source: Source? = nil
        var supervisor: Supervisor? = nil
        
        private func download(to destination: Path) async throws -> Void {
            self.status = .downloading
            
            if destination.exists() {
                try destination.remove()
            }
            
            guard let url = source?.url else {
                throw VM.InstallerDownloadError.cannotRetrieveSourceURL
            }
            
            try await fetch(
                from: url,
                saveTo: destination,
                didProgress: { progress in
                    self.progress = progress.fractionCompleted
                }
            )
        }

        private func verify(at downloaded: Path?) async throws -> Void {
            self.status = .verifying
            
            guard let cdrom = downloaded else {
                throw VM.InstallerVerificationError.cannotVerifyNotDownloadedCDROM
            }
            
            let task = Task {
                try cdrom.checksum(binary: true)
            }
            
            let checksum = try await task.value
            
            guard let expected = source?.checksum else {
                throw InstallerVerificationError.unexpectedInternalChecksum
            }
            
            if !expected.matches(checksum) {
                throw InstallerVerificationError.failedVerificationCheck
            }
        }
        
        private func configure(_ name: String, _ image: Path, _ specs: VM.Specification) async throws -> Void {
            func cleanup(_ vm: VM) {
                vm.storage.erase()
            }
            
            self.status = .configuring
            
            let vm = try VM(
                name: name,
                specs: specs,
                guest: VM.Guest(
                    name: name,
                    image: image
                ),
                devices: nil
            )
            
            guard let disk = vm.devices.first(where: { $0 is Device.Disk }) as? Device.Disk else {
                cleanup(vm)
                throw InstallerConfigurationError.diskNotFoundInVMsInternalDevices
            }
            
            let task = Task {
                try disk.truncate()
            }
            
            guard await (try? task.result.get()) != nil else {
                cleanup(vm)
                throw InstallerConfigurationError.diskCreationFailed
            }
            
            do {
                try vm.configure()
            } catch {
                cleanup(vm)
            }
            
            guard let supervisor = self.supervisor else {
                cleanup(vm)
                throw InstallerConfigurationError.supervisorUninitialised
            }
            
            supervisor.add(vm)
            vm.backup()
        }
        
        /**
         * Begins the full installation from square one.
         */
        func install(name: String, specs: VM.Specification) async throws -> Void {
            
            // Just some basic checks to see if a VM
            // can be created without issues.
            for check in checks {
                let result = check(name, specs)
                
                if !result.passed {
                    guard let reason = result.reason else {
                        throw InstallerConfigurationCheckError.failed(
                            reason: "Something went wrong!"
                        )
                    }
                    
                    throw InstallerConfigurationCheckError.failed(reason: reason)
                }
            }
            
            active = true
            progress = -1
            source = specs.source
            
            let destination = Path(.Places.isos, "\(specs.source.name).iso")
            
            defer {
                active = false
                progress = -1
                status = nil
                source = nil
            }
            
            // Only downloads if needed.
            if !destination.exists() {
                try await download(to: destination)
            }
            
            try await self.verify(at: destination)
            
            try await self.configure(
                name,
                destination,
                specs
            )
        }
    }
}

// ------
// Errors
// ------

extension VM {
    enum InstallerDownloadError: Error {
        case cannotRetrieveSourceURL
        
        var message: String {
            switch self {
            case .cannotRetrieveSourceURL:
                return "Failed to retrieve the source's URL!"
            }
        }
    }
    
    enum InstallerVerificationError: Error {
        case cannotVerifyNotDownloadedCDROM
        case unexpectedInternalChecksum
        case failedVerificationCheck
        
        var message: String {
            switch self {
            case .cannotVerifyNotDownloadedCDROM:
                return "Cannot verify a CDROM image which isn't yet downloaded!"
            case .unexpectedInternalChecksum:
                return "An internal error occurred trying to get the expected checksum!"
            case .failedVerificationCheck:
                return "The verification process failed to verify that the file downloaded isn't corrupt or tampered with!"
            }
        }
    }
    
    enum InstallerConfigurationError: Error {
        case diskNotFoundInVMsInternalDevices
        case diskCreationFailed
        case supervisorUninitialised
        
        var message: String {
            switch self {
            case .diskNotFoundInVMsInternalDevices:
                return "Disk not found in VM's internal devices!"
            case .diskCreationFailed:
                return "Failed to create a new disk for the VM!"
            case .supervisorUninitialised:
                return "An internal error occurred trying to use an uninitialised supervisor!"
            }
        }
    }
    
    enum InstallerConfigurationCheckError: Error {
        case failed(reason: String)
    }
}
