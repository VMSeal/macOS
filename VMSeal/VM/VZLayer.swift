//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  VZLayer.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-18.
//

import Foundation
import Virtualization
import os

@Observable
@MainActor
class VZLayer {
    /**
     * Observer which watches changes in the `VZVirtualMachine.State` so we can use the values reactively.
     */
    @Observable
    class VZLayerVirtualMachineStateObserver {
        var state: VZVirtualMachine.State
        
        private var vm: VZVirtualMachine
        private var observation: NSKeyValueObservation?
        
        init(vm: VZVirtualMachine) {
            self.state = .stopped
            
            self.vm = vm
            self.observation = nil
            
            self.observation = self.vm.observe(\.state, options: [.new]) { vm, change in
                self.state = vm.state
            }
        }
    }
    
    static func initEFIVariableStore(at url: URL) throws {
        let _ = try VZEFIVariableStore(creatingVariableStoreAt: url)
    }
    
    private let machineConfig: VM.Configuration
    
    private(set) var vzConfig: VZVirtualMachineConfiguration
    private(set) var vzVirtualMachine: VZVirtualMachine?
    private(set) var vzStateObserver: VZLayerVirtualMachineStateObserver?
    var vzDelegate: VZVirtualMachineDelegate?
    
    /**
     * A callback provided by the consumer of `VZLayer` which we call when an unexpected error forces the VM to stop.
     */
    var fatalErrorDidOccur: @MainActor @Sendable (any Error) -> Void
    
    init(config machineConfig: VM.Configuration) {
        self.vzDelegate = nil
        self.vzConfig = VZVirtualMachineConfiguration()
        self.vzVirtualMachine = nil
        self.vzStateObserver = nil
        
        self.machineConfig = machineConfig
        
        self.fatalErrorDidOccur = { _ in }
    }
    
    /**
     * Gets the display device of a running VZ VM.
     * Returns: `nil` if the display cannot be accessed; otherwise `VZGraphicsDisplay`.
     */
    var display: VZGraphicsDisplay? {
        guard let vm = self.vzVirtualMachine else {
            return nil
        }
        
        guard vm.state == .running else {
            return nil
        }
        
        guard let rv = vm.graphicsDevices.first?.displays.first else {
            return nil
        }
        
        return rv
    }
    
    /**
     * Unset various `vz`-prefixed properties; called after the VM stops.
     */
    private func cleanup() {
        self.vzVirtualMachine = nil
        self.vzStateObserver = nil
    }
    
    /**
     * Sets up the underlying `VZVirtualMachineConfiguration` and all devices, and validates the configuration.
     */
    func configure(
        efiVariableStore: URL,
        iso: URL,
        disk: URL,
        displayWidthInPixels: Int,
        displayHeightInPixels: Int
    ) throws {
        self.vzConfig = VZVirtualMachineConfiguration()
        
        self.vzConfig.memorySize = machineConfig.memoryInBytes.asUInt64
        self.vzConfig.cpuCount = machineConfig.vCPUs
       
        let parcel = VZLayer.Component.Parcel(
            efiVariableStore: efiVariableStore,
            iso: iso,
            disk: disk,
            displayWidthInPixels: displayWidthInPixels,
            displayHeightInPixels: displayHeightInPixels
        )
        
        for (_, initialiseComponent) in VZLayer.Component.initialisers {
            try initialiseComponent(self.vzConfig, parcel)
        }
        
        do {
            try self.vzConfig.validate()
        } catch let e as VZError {
            switch e.code {
            case .invalidVirtualMachineConfiguration:
                throw VirtConfigError.invalidConfig(message: e.localizedDescription)
            case .invalidDiskImage:
                throw VirtConfigError.invalidDisk(message: e.localizedDescription)
            default:
                throw VirtConfigError.other(message: e.localizedDescription)
            }
        }
    }
    
    func removeCDROM() -> Bool {
        let maybeIndex = self.vzConfig.storageDevices.lastIndex {
            guard $0 is VZVirtioBlockDeviceConfiguration else {
                return false
            }
            
            let attachment = $0.attachment
            
            guard attachment is VZDiskImageStorageDeviceAttachment else {
                return false
            }
            
            return (attachment as! VZDiskImageStorageDeviceAttachment)
                .isReadOnly
        }
        
        guard let index = maybeIndex else {
            return false
        }
        
        self.vzConfig.storageDevices.remove(at: index)
        return true
    }
    
    /**
     * Low-level lifecycle hook at the VZ-layer which fires when the VM starts.
     */
    func start() async throws {
        self.vzVirtualMachine = VZVirtualMachine(configuration: self.vzConfig)
        self.vzStateObserver = VZLayerVirtualMachineStateObserver(vm: self.vzVirtualMachine!)
        
        guard self.vzVirtualMachine!.canStart else {
            throw VirtStartupError.cannotStart
        }
        
        if let delegate = self.vzDelegate {
            self.vzVirtualMachine!.delegate = delegate
        }
        
        do {
            try await self.vzVirtualMachine!.start()
        } catch let e {
            self.vzVirtualMachine = nil
            self.vzStateObserver = nil
            throw VirtStartupError.other(message: e.localizedDescription)
        }
    }
    
    /**
     * Low-level lifecycle hook at the VZ-layer which fires when the VM stops.
     */
    func stop() async throws {
        guard self.vzVirtualMachine != nil else {
            return
        }
        
        guard self.vzVirtualMachine!.canStop else {
            throw VirtShutdownError.cannotStop
        }
        
        if self.vzVirtualMachine!.state != .stopped || self.vzVirtualMachine!.state != .stopping {
            do {
                try await self.vzVirtualMachine!.stop()
                self.cleanup()
            } catch let e {
                throw VirtShutdownError.other(message: e.localizedDescription)
            }
        }
    }
}
