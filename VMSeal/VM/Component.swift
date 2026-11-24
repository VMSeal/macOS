//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Component.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-19.
//

import Virtualization

extension VZLayer {
    /**
     * A definition of configurable components (i.e. devices & features supported inside the VM).
     */
    enum Component {
        case bootloader
        case cdrom
        case disk
        case display
        case entropy
        case keyboard
        case mouse
        case network
        case platform
        case speakers
        
        /**
         * Represents options which are sent as a "parcel" to the component initialiser map's respective closures.
         */
        struct Parcel {
            // -- Files --
            let efiVariableStore: URL
            let iso: URL
            let disk: URL
            
            // -- Display-specific --
            
            let displayWidthInPixels: Int
            let displayHeightInPixels: Int
        }
        
        /**
         * Map of closures which configures (initialises) their respective components and reflects this in the `VZVirtualMachineConfiguration` of `VZLayer`.
         */
        static let initialisers: [VZLayer.Component: (_: VZVirtualMachineConfiguration, _: Parcel) throws -> Void] = [
            .bootloader: { vzConfig, parcel in
                let bootloader = VZEFIBootLoader()
                bootloader.variableStore = VZEFIVariableStore(url: parcel.efiVariableStore)
                
                vzConfig.bootLoader = bootloader
            },
            .cdrom: { vzConfig, parcel in
                let diskImageConfig = VZVirtioBlockDeviceConfiguration(
                    attachment: try VZDiskImageStorageDeviceAttachment(
                        url: parcel.iso,
                        readOnly: true
                    )
                )
                
                vzConfig.storageDevices.insert(diskImageConfig, at: 0)
            },
            .disk: { vzConfig, parcel in
                let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(url: parcel.disk, readOnly: false)
                let diskConfig = VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
                
                vzConfig.storageDevices.append(diskConfig)
            },
            .display: { vzConfig, parcel in
                let graphicsDeviceConfig = VZVirtioGraphicsDeviceConfiguration()
                
                let scanoutConfig = VZVirtioGraphicsScanoutConfiguration(
                    widthInPixels: parcel.displayWidthInPixels,
                    heightInPixels: parcel.displayHeightInPixels
                )
                
                graphicsDeviceConfig.scanouts = [scanoutConfig]
                vzConfig.graphicsDevices = [graphicsDeviceConfig]
            },
            .entropy: { vzConfig, _ in
                vzConfig.entropyDevices = [
                    VZVirtioEntropyDeviceConfiguration()
                ]
            },
            .keyboard: { vzConfig, _ in
                vzConfig.keyboards = [
                    VZUSBKeyboardConfiguration()
                ]
            },
            .mouse: { vzConfig, _ in
                vzConfig.pointingDevices = [
                    VZUSBScreenCoordinatePointingDeviceConfiguration()
                ]
            },
            .network: { vzConfig, _ in
                let networkConfig = VZVirtioNetworkDeviceConfiguration()
                let natAttachment = VZNATNetworkDeviceAttachment()
                
                networkConfig.attachment = natAttachment
                vzConfig.networkDevices = [networkConfig]
            },
            .platform: { vzConfig, _ in
                let vzPlatform = VZGenericPlatformConfiguration()
                vzPlatform.machineIdentifier = VZGenericMachineIdentifier()
                
                vzConfig.platform = vzPlatform
            },
            .speakers: { vzConfig, _ in
                let soundDeviceConfig = VZVirtioSoundDeviceConfiguration()
                let soundDeviceOutputStreamConfig = VZVirtioSoundDeviceOutputStreamConfiguration()
                let hostAudioOutputSink = VZHostAudioOutputStreamSink()
                
                soundDeviceOutputStreamConfig.sink = hostAudioOutputSink
                
                soundDeviceConfig.streams = [soundDeviceOutputStreamConfig]
                vzConfig.audioDevices = [soundDeviceConfig]
            }
        ]
    }
}
