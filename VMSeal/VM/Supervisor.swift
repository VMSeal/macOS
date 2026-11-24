//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Supervisor.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-02-21.
//

import Foundation
import Virtualization

/**
 * The supervisor's responsibility is to manage the lifecycle of the user's VMs.
 */
@Observable
@MainActor
class Supervisor {
    enum Error: Swift.Error {
        case invalidMachineId(uuid: String)
        case missingMachineConfig
        case vmNotStopped
    }
    
    private class MyDelegate: VM.Delegate {
        func fatalErrorDidOccur(_ error: any Swift.Error) {
            
        }
    }
    
    private let myDelegate: MyDelegate
    private var vms: [VM]
    
    init(vms: [VM] = []) {
        self.vms = vms
        self.myDelegate = MyDelegate()
    }
    
    var allSupervised: [VM] {
        self.vms
    }
    
    func indexOf(machine: VM) throws -> Array<VM>.Index {
        guard let index = self.vms.firstIndex(where: { $0.id == machine.id }) else {
            throw Error.invalidMachineId(uuid: machine.id.uuidString)
        }
        
        return index
    }
    
    func supervises(machine: VM) -> Bool {
        return self.vms.contains {
            $0.id == machine.id
        }
    }
    
    /**
     * Restores a single specific machine which isn't loaded in the supevisor's memory.
     */
    func restore(id: UUID) async throws {
        let storage = VM.Storage(id) // only used temporarily to find paths
        
        guard storage.base.local.exists() else {
            throw Error.invalidMachineId(uuid: id.uuidString)
        }
        
        let configFile = storage.files[.configStore]!
        
        guard let raw = try? configFile.local.readString() else {
            throw Error.missingMachineConfig
        }
        
        let config: VM.Configuration = try JSON.decode(from: raw)
        
        self.supervise(
            machine: VM(config: config, delegate: self.myDelegate, id: id)
        )
    }
    
    func rename(machine: VM, to newName: String) throws {
        let oldName = machine.config.name
        
        do {
            machine.config.name = newName
            try machine.storage.save(configuration: machine.config)
        } catch let e {
            machine.config.name = oldName
            throw e
        }
    }
    
    func supervise(machine: VM) {
        try? machine.bootstrap()
        self.vms.append(machine)
        
        if machine.delegate == nil {
            machine.delegate = self.myDelegate
        }
    }
    
    func unsupervise(machine: VM) throws -> VM {
        let index = try self.indexOf(machine: machine)
        
        return self.vms.remove(at: index)
    }
    
    /**
     * Restores all VMs stored on disk into the supervisor's memory.
     */
    func restoreAll() async throws {
        let ids = VM.Storage.machines
        
        // No need to wait for the result.
        do {
            for id in ids {
                try await self.restore(id: id)
            }
        } catch let e {
            self.vms = []
            throw e
        }
    }
    
    func edit(machine: VM, toConfig newConfig: VM.Configuration) throws {
        let oldConfig = machine.config
        
        guard machine.state == .stopped else {
            throw Error.vmNotStopped
        }
        
        do {
            machine.config = newConfig
            try machine.storage.save(configuration: newConfig)
        } catch let e {
            machine.config = oldConfig
            throw e
        }
    }
    
    func start(machine: VM) async throws {
        try await machine._start()
    }
    
    func stop(machine: VM) async throws {
        try await machine._stop()
    }
    
    func delete(machine: VM) async throws {
        let machine = try self.unsupervise(machine: machine)
        
        try? await self.stop(machine: machine)
        
        Task {
            // TODO: error handling
            try? machine.storage.erase()
        }
    }
}
