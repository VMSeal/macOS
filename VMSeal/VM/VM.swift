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

import Foundation
import Virtualization


@Observable
@MainActor
class VM: Identifiable {
    struct Storage {
        enum File {
            case diskImage
            case efiVariableStore
            case configStore
        }
        
        /**
         * The name of the directory which stores data of all machines.
         */
        static private let machineStorageDirectoryName = "VMs"
        
        /**
         * Property which returns the UUIDs of **all** machines stored on disk.
         */
        static var machines: [UUID] {
            guard let ids = try? FileManager.default.contentsOfDirectory(
                atPath: URL.LocalURL.app
                    .appendingPathComponent(Self.machineStorageDirectoryName)
                    .path()
            ) else {
                return []
            }
            
            var rv: [UUID] = []
            
            for id in ids {
                guard let uuid = UUID(uuidString: id) else {
                    continue
                }
                
                rv.append(uuid)
            }
            
            return rv
        }
        
        /**
         * Resolves the location URL of an arbitrary machine.
         */
        static func resolve(machineId: UUID) -> URL {
            URL.LocalURL.app
                .appendingPathComponent(Self.machineStorageDirectoryName)
                .appendingPathComponent(machineId.uuidString)
        }
        
        let files: [Self.File : URL]
        let base: URL
        
        init(_ machineId: UUID) {
            self.base = Self.resolve(machineId: machineId)
            
            self.files = [
                .diskImage: self.base.appendingPathComponent("Disk"),
                .efiVariableStore: self.base.appendingPathComponent("EFI-Variable-Store"),
                .configStore: self.base.appendingPathComponent("Configuration.json")
            ]
        }
        
        /**
         * Saves the VM's configuration onto disk.
         */
        func save(configuration: VM.Configuration) throws {
            let serialisedConfig = try JSON.encode(from: configuration)
            try self.files[.configStore]!.local.writeString(content: serialisedConfig)
        }
        
        /**
         * Erases all stored data of the machine.
         */
        func erase() throws {
            try self.base.local.remove()
        }
        
        /**
         * Bootstraps the storage needed by the machine (if needed).
         * Don't call this directly; use `Machine.bootstrap()` instead.
         */
        func bootstrap(config: VM.Configuration) throws {
            // The directory already exists if an error is thrown, so ignore it.
            try? self.base.local.mkdir()
            
            // Disk Image
            if (!self.files[.diskImage]!.local.exists()) {
                try DiskUtil.truncate(
                    at: self.files[.diskImage]!,
                    size: config.diskSizeInBytes
                )
            }
            
            // EFI Variable Store
            if (!self.files[.efiVariableStore]!.local.exists()) {
                try VZLayer.initEFIVariableStore(at: self.files[.efiVariableStore]!)
            }
            
            // Config Store
            if (!self.files[.configStore]!.local.exists()) {
                try self.files[.configStore]!.local.writeString(content: "{}")
            }
        }
    }
    
    struct Configuration: Identifiable, Codable, Hashable {
        // -- Specs --
        var diskSizeInBytes: Double
        var memoryInBytes: Double
        var vCPUs: Int
        
        // -- Files --
        var iso: URL?
        
        // -- Display-specific --
        var displayWidthInPixels: Int = 1920
        var displayHeightInPixels: Int = 1080
        
        // -- Metadata --
        var name: String
        var isFirstBoot: Bool = true
        
        var id: UUID {
            UUID()
        }
        
        static var defaults: VM.Configuration {
            VM.Configuration(
                diskSizeInBytes: VM.Requirements.DiskSize.recommended,
                memoryInBytes: VM.Requirements.Memory.recommended,
                vCPUs: VM.Requirements.CPU.recommended,
                name: ""
            )
        }
    }
    
    protocol Delegate {
        func fatalErrorDidOccur(_: any Error)
    }
    
    private class StubDelegate: Delegate {
        func fatalErrorDidOccur(_: any Error) {
            return
        }
    }
    
    private class MyVZDelegate: NSObject, VZVirtualMachineDelegate {
        private let vm: VM
        private let highLevelDelegate: VM.Delegate?
        
        init(vm: VM, highLevelDelegate: VM.Delegate?) {
            self.vm = vm
            self.highLevelDelegate = highLevelDelegate
        }
        
        func guestDidStop(_ virtualMachine: VZVirtualMachine) {
            Task {
                try? await self.vm._stop(guestDidStop: true)
            }
        }
        
        func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
            guard let delegate = self.highLevelDelegate else {
                return
            }
            
            Task {
                delegate.fatalErrorDidOccur(error)
            }
        }
    }
    
    typealias State = VZVirtualMachine.State
    
    enum CDROMStatus {
        case inserted
        case ejected
    }
    
    /**
     * This is the low-level layer that `VM` talks to and which does the bulk of the work.
     * **DO NOT** rely on this underlying API externally unless you have a really good reason to.
     */
    let vz: VZLayer

    typealias ID = UUID
    let id: ID
    
    let storage: Storage
    
    var config: Configuration
    var delegate: Delegate?

    var state: State {
        self.vz.vzStateObserver?.state ?? .stopped
    }
    
    /**
     * Property which represents the display's dimensions of the currently running VM.
     * This property may be set and will update the display.
     *
     * **IMPORTANT:** This property only works when the VM is running, and will in that case neither get, nor set, any values.
     */
    var displaySize: CGSize? {
        get {
            self.vz.display?.sizeInPixels
        }
        set {
            guard let newSize = newValue else {
                return
            }
            
            try? self.vz.display?.reconfigure(sizeInPixels: newSize)
        }
    }
    
    /**
     * **NOTE:** There is *usually* no need to manually specify a UUID when instantiating this class: it will generate one itself if needed.
     */
    init(config: Configuration, delegate: Delegate? = nil, id: UUID = UUID()) {
        self.vz = VZLayer(config: config)
        self.id = id
        self.config = config
        self.storage = VM.Storage(self.id)
        
        self.delegate = delegate
        self.vz.vzDelegate = MyVZDelegate(vm: self, highLevelDelegate: self.delegate)
    }
    
    /**
     * Wires up the VM's config and makes it ready for running.
     */
    func bootstrap() throws {
        try self.storage.bootstrap(config: self.config)
        
        try self.vz.configure(
            efiVariableStore: self.storage.files[.efiVariableStore]!,
            iso: self.config.iso!,
            disk: self.storage.files[.diskImage]!,
            displayWidthInPixels: self.config.displayWidthInPixels,
            displayHeightInPixels: self.config.displayHeightInPixels,
        )
        
        Task {
            // TODO: add proper error handling
            try? self.storage.save(configuration: self.config)
        }
    }
    
    /**
     * **DO NOT** call this method directly -- it is only intended to be used by the `Supervisor`
     */
    func _start() async throws {
        try self.bootstrap()
        
        if !self.config.isFirstBoot {
            guard self.vz.removeCDROM() else {
                throw VirtConfigError.other(message: "Failed to eject CDROM")
            }
        }
        
        try await self.vz.start()
    }
    
    /**
     * **DO NOT** call this method directly -- it is only intended to be used by the `Supervisor`.
     */
    func _stop(guestDidStop: Bool = false) async throws {
        
        // No need to trigger a shutdown which will trigger an error if the guest already has shut down.
        if !guestDidStop {
            try await self.vz.stop()
        }
        
        let wasFirstBoot = self.config.isFirstBoot
        self.config.isFirstBoot = false
        try self.storage.save(configuration: self.config)
        
        // Indicates that we need to boot it again to finish setup of VMSeal/OS.
        // Comparing against `true` directly for clarity's sake.
        if guestDidStop && wasFirstBoot {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms
            try await self._start()
        }
    }
}
