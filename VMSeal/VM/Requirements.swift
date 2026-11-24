//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Requirements.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-22.
//


import Foundation
import Virtualization


extension VM {
    protocol Requirement<T> {
        static var minimum: T { get }
        static var maximum: T { get }
        
        static var recommended: T { get }
        
        associatedtype T
    }
    
    struct Requirements {
        struct Memory: Requirement {
            // in bytes, returns for 2 MiB e.g., 2_097_152 bytes.
            static var minimum: Double {
                Double(
                    VZVirtualMachineConfiguration.minimumAllowedMemorySize
                )
            }
            
            // See comment for previous member.
            static var maximum: Double {
                Double(
                    VZVirtualMachineConfiguration.maximumAllowedMemorySize
                )
            }
            
            // See comment for first member.
            static var recommended: Double {
                let goal = 2.GiB
                
                if goal < Memory.minimum {
                    return Memory.minimum
                }
                
                if goal > Memory.maximum {
                    return Memory.maximum
                }
                
                return goal
            }
        }
        
        struct CPU: Requirement {
            static var minimum: Int {
                VZVirtualMachineConfiguration.minimumAllowedCPUCount
            }
            
            static var maximum: Int {
                min(VZVirtualMachineConfiguration.maximumAllowedCPUCount, 32)
            }
            
            static var recommended: Int {
                let goal = 4
                
                if goal < CPU.minimum {
                    return CPU.minimum
                }
                
                if goal > CPU.maximum {
                    return CPU.maximum
                }
                
                return goal
            }
        }
        
        struct DiskSize: Requirement {
            static var minimum: Double {
                8.GiB
            }
            
            static var maximum: Double {
                min(DiskUtil.freeDiskSpaceInBytes, 128.GiB)
            }
            
            static var recommended: Double {
                let goal = 16.GiB
                
                if goal < DiskSize.minimum {
                    return DiskSize.minimum
                }
                
                if goal > DiskSize.maximum {
                    return DiskSize.maximum
                }
                
                return goal
            }
        }
    }
}
