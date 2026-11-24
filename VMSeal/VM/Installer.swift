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
//  Created by Axel H. Karlsson on 2026-11-20.
//

import Foundation

@Observable
@MainActor
class Installer {
    
    /**
     * Includes neccessary metadata about the ISO the installer will download.
     */
    struct Source {
        enum Error: Swift.Error {
            case insecureURLScheme
            case downloadsDirectoryNotFound
        }
        
        /**
         * Filename of the downloaded ISO.
         */
        let filename: String
        
        /**
         * Remote HTTPS URL where the ISO to download exists.
         */
        let iso: URL
        
        /**
         * Used to verify that the ISO hasn't been corrupted.
         */
        let checksum: SHA256Sum
        
        /**
         * Suggested local URL where the ISO may be stored.
         */
        var destination: URL {
            URL.LocalURL.iso
                .appendingPathComponent(self.filename)
        }
        
        init(iso: URL, checksum: SHA256Sum, filename: String) {
            self.iso = iso
            self.checksum = checksum
            self.filename = filename
        }
    }
    
    enum Error: Swift.Error {
        case invalidDownloadURL
        case checksumMismatch
        case installerAlreadyConsumed
    }
    
    enum Status: String {
        case downloading = "Downloading ISO..."
        case validating = "Validating ISO..."
        case configuring = "Configuring VM..."
        case completed = "Completed!"
    }
    
    class Parcel {
        /**
         * See `Source`'s  doc-comment above.
         */
        let source: Installer.Source
        
        /**
         * The configuration to use for the new VM.
         * Do note that steps may (and will) mutate this configuration.
         */
        var config: VM.Configuration
        
        /**
         * The resulting finished installed VM of the installer.
         */
        var result: VM?
        
        init(source: Installer.Source, config: VM.Configuration) {
            self.source = source
            self.config = config
            self.result = nil
        }
    }
    
    private var steps: [[Status : () async throws -> Void]] {
        [
            [.downloading: self.download],
            [.validating: self.validate],
            [.configuring: self.configure]
        ]
    }
    
    private var parcel: Parcel
    
    let source: Source
    let config: VM.Configuration
    
    var status: Status?
    
    /**
     * Download progress-indicator.
     */
    var progress: Double
    
    init(source: Source? = nil, config: VM.Configuration? = nil) {
        self.source = source ?? Constant.source
        self.config = config ?? VM.Configuration(
            diskSizeInBytes: VM.Requirements.DiskSize.recommended,
            memoryInBytes: VM.Requirements.Memory.recommended,
            vCPUs: VM.Requirements.CPU.recommended,
            name: "Unnamed VM"
        )
        
        self.status = nil
        self.progress = -1
        
        self.parcel = Parcel(source: self.source, config: self.config)
    }
    
    /**
     * Downloads the bootable media from specified source.
     */
    private func download() async throws {
        let source = self.parcel.source
        let destination = source.destination

        if destination.local.exists() {
            try destination.local.remove()
        }
        
        if !URL.LocalURL.iso.local.exists() {
            try destination.local.mkdir()
        }
        
        defer {
            self.progress = -1
        }
        
        try await fetch(
            from: source.iso,
            saveTo: destination,
            didProgress: { progress in
                self.progress = progress.fractionCompleted
            }
        )
    }
    
    /**
     * Validates the downloaded bootable media.
     */
    private func validate() async throws {
        let destination = self.parcel.source.destination
        let checksum = self.parcel.source.checksum
        
        let calculateDigestTask = Task {
            try destination.local.checksum(binary: true)
        }
        
        let actual = try await calculateDigestTask.value
        
        guard checksum.matches(actual) else {
            throw Installer.Error.checksumMismatch
        }
    }
    
    private func configure() async throws {
        let config = self.parcel.config
        let vm = VM(config: config)
        
        self.parcel.result = vm
    }
    
    func start() async throws -> VM {
        guard self.status == nil else {
            throw Error.installerAlreadyConsumed
        }
        
        self.parcel = Parcel(
            source: self.source,
            config: self.config
        )
        
        if self.parcel.config.iso == nil {
            self.parcel.config.iso = self.source.destination
        }
        
        defer {
            self.status = .completed
        }
        
        for step in steps {
            let assignedStepStatus = step.keys.first!
            let handler = step.values.first!
            
            self.status = assignedStepStatus
            
            do {
                // Mutate the parcel for the next install step handler
                try await handler()
            } catch let e {
                self.abort()
                throw e
            }
        }
        
        return self.parcel.result!
    }
    
    func abort() {
        try? self.source.destination.local.remove()
    }
}
