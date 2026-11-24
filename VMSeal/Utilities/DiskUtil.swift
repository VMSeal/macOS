//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  DiskUtil.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-18.
//

import Foundation

enum DiskUtil {
    enum DiskError: Error {
        case fileDescriptorInvalid
        case truncationFailed
        case closingFileDescriptorFailed
    }
    
    static func truncate(at url: URL, size: Double) throws -> Void {
        let fd = unsafe open(url.path(), O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        
        guard fd >= 0 else {
            throw DiskError.fileDescriptorInvalid
        }
        
        let ftruncateStatus = ftruncate(fd, size.asInt64)
        
        guard ftruncateStatus == 0 else {
            throw DiskError.truncationFailed
        }
        
        let closeFdStatus = close(fd)
        
        guard closeFdStatus == 0 else {
            throw DiskError.closingFileDescriptorFailed
        }
    }
    
    static var freeDiskSpaceInBytes: Double {
        let root = URL(fileURLWithPath: "/")
        
        let values = try? root.resourceValues(
            forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey]
        )
        
        return Double(
            exactly: values?.volumeAvailableCapacityForOpportunisticUsage ?? 0
        ) ?? 0
    }
}
