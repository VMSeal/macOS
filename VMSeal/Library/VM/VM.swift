//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  VM.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-02-15.
//

import Virtualization
import Foundation
import SwiftData
import SwiftUI

@Observable
class VM: Identifiable {
    var name: String
    
    var memory: Double
    var vCPUs: Double
    
    var diskSize: Double
    
    var storage: VM.Storage
    var devices: [Device.Configurable]
    
    let guest: VM.Guest
    
    var vm: VZVirtualMachine?
    var configuration: VZVirtualMachineConfiguration
    
    var display: VZGraphicsDisplay? {
        get {
            guard let vm = vm else {
                return nil
            }
            
            // Too lazy to check for multiple displays,
            // and, to be honest, will likely never get implemented.
            
            guard vm.graphicsDevices.count == 1 else {
                fatalError("Currently, only one graphics device is supported.")
            }
            
            guard vm.graphicsDevices.first!.displays.count == 1 else {
                fatalError("Currently, only one display device is supported.")
            }
            
            guard let display = vm.graphicsDevices.first!.displays.first else {
                return nil
            }
            
            
            return display
        }
    }
    
    let cdrom: VM.CDROM
    
    private var stateObserver: VM.StateObserver? = nil
    
    var state: VZVirtualMachine.State {
        self.stateObserver?.state ?? .stopped
    }
    
    var path: Path {
        storage.path
    }
    
    static func getDefaultDevices(diskSize: Double, storage: VM.Storage) throws -> [Device.Configurable] {
        return try [
            Device.Bootloader(efiVariableStore: storage.EFIVariableStore),
            Device.Platform(),
            Device.Entropy(),
            
            Device.Network(),
            Device.Audio(),
            
            Device.Disk(size: diskSize, at: storage.Disk),
            
            Device.Display(width: 1920, height: 1080),
            Device.Keyboard(),
            Device.Mouse()
        ]
    }
    
    init(
        from name: String,
        devices: [Device.Configurable]?
    ) throws {
        let storage = VM.Storage(vm: name)
        self.storage = storage
        
        let specs: VM.Storage.Backup = try JSON.decode(
            at: storage.Configuration
        )
        
        self.name = name
        
        self.memory = specs.memory
        self.vCPUs = specs.vCPUs
        self.diskSize = specs.diskSize
        
        self.guest = specs.guest
        
        self.devices = try devices ?? VM.getDefaultDevices(
            diskSize: specs.diskSize,
            storage: storage
        )
        
        self.configuration = VZVirtualMachineConfiguration()
        
        self.cdrom = VM.CDROM(state: specs.cdrom)
        
        // Make sure CDROM is removed if backup indicates so.
        if self.cdrom.state == .inserted {
            try self.cdrom.eject(vm: self)
        }
    }
    
    init(
        name: String,
        specs: VM.Specification,
        guest: VM.Guest,
        devices: [Device.Configurable]?
    ) throws {
        self.name = name
        
        self.memory = specs.memory
        self.vCPUs = specs.vCPUs
        self.diskSize = specs.diskSize
        
        self.guest = guest
        
        let storage = VM.Storage(vm: name)
        try storage.create()
        
        self.storage = storage
        
        self.devices = try devices ?? VM.getDefaultDevices(
            diskSize: specs.diskSize,
            storage: storage
        )
        
        self.configuration = VZVirtualMachineConfiguration()
        
        // CDROM is inserted by default.
        self.cdrom = VM.CDROM(state: .inserted)
        try self.cdrom.insert(vm: self)
    }
    
    func backup() -> Void {
        try? self.storage.backup(
            backup: VM.Storage.Backup(
                memory: self.memory,
                diskSize: self.diskSize,
                vCPUs: self.vCPUs,
                guest: self.guest,
                cdrom: self.cdrom.state
            )
        )
    }
    
    func configure() throws -> Void {
        
        // Clear existing configuration, if any
        self.configuration = VZVirtualMachineConfiguration()
        
        self.configuration.memorySize = self.memory.asUInt64
        self.configuration.cpuCount = self.vCPUs.asInt
        
        do {
            for device in self.devices {
                try device.configure(configuration: self.configuration)
            }
        } catch {
            throw VM.ConfigurationError.failedDeviceConfiguration
        }
        
        try self.configuration.validate()
        
        // TODO: Is this really necessary? Can this be removed?
        self.backup()
    }
    
    func start() async throws {
        do {
            self.vm = VZVirtualMachine(
                configuration: self.configuration
            )
            
            self.stateObserver = VM.StateObserver(vm: self.vm!)
            
            try await self.vm!.start()
        } catch {
            throw VM.ConfigurationError.failedToStartVM
        }
    }
    
    func stop() {
        self.vm?.stop { error in
            
            // Attempt to request stop if force-stopping fails
            guard error != nil else {
                try? self.vm?.requestStop()
                return
            }
            
            self.stateObserver = nil
        }
    }
    
    func rename(to newName: String) throws {
        if self.state != .stopped {
            throw VM.RuntimeError.cannotRenameWhenPoweredOn
        }
        
        self.name = newName
        try self.storage.rename(to: newName)
        
        // We need to reconfigure the VM's hard disk and EFI store & more
        // for the VM to be fully up-to-date with its new path.
        
        self.devices = try Self.getDefaultDevices(
            diskSize: self.diskSize,
            storage: storage
        )
        
        try self.configure()
        self.backup()
    }
}

extension VM {
    @Observable
    class CDROM {
        enum State: Codable {
            case inserted
            case ejected
        }
        
        var state: State
        
        init(state: State) {
            self.state = state
        }
        
        /**
         * **NOTE:** running `vm.configure()` and rebooting the VM is required for this to take effect!
         */
        func insert(vm: VM) throws -> Void {
            // Already inserted
            if vm.devices.contains(where: { $0 is Device.CDROM }) {
                return
            }
            
            vm.devices.append(
                Device.CDROM(from: vm.guest.image)
            )
            
            self.state = .inserted
        }
        
        /**
         * **NOTE:** running `vm.configure()` and rebooting the VM is required for this to take effect!
         */
        func eject(vm: VM) throws -> Void {
            vm.devices.removeAll {
                $0 is Device.CDROM
            }
            
            self.state = .ejected
        }
        
        /**
         * High-level function for toggling the CDROM presence.  
         * **NOTE:** This function reconfigures the VM provided and requires it to be shutdown.
         */
        func toggle(vm: VM) throws -> Void {
            
            if vm.state != .stopped {
                throw VM.RuntimeError.failedToInsertOrEjectCDROM
            }
            
            if self.state == .ejected {
                try vm.cdrom.insert(vm: vm)
            } else {
                try vm.cdrom.eject(vm: vm)
            }
            
            try vm.configure()
        }
    }
}

// ------
// Errors
// ------

extension VM {
    enum RuntimeError: Error {
        case failedToInsertOrEjectCDROM
        case cannotRenameWhenPoweredOn
        
        var message: String {
            switch self {
            case .failedToInsertOrEjectCDROM:
                return "Failed to insert or eject a CDROM!"
            case .cannotRenameWhenPoweredOn:
                return "Cannot rename a VM which is powered on!"
            }
        }
    }
    
    enum ConfigurationError: Error {
        case failedDeviceConfiguration
        case failedToStartVM
        case failedToStopVM
        
        var message: String {
            switch self {
            case .failedDeviceConfiguration:
                return "Failed to configure the VM's devices!"
            case .failedToStartVM:
                return "Failed to start the VM!"
            case .failedToStopVM:
                return "Failed to stop the VM!"
            }
        }
    }
}
