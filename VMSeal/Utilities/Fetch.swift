//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Fetch.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-16.
//

import Foundation

private class FetchDelegate: NSObject, URLSessionTaskDelegate {
    
    var observation: NSKeyValueObservation? = nil
    
    let didProgress: (Progress) -> Void
    
    init(_ didProgress: @escaping (Progress) -> Void) {
        self.didProgress = didProgress
    }
    
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) -> Void {
        observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            self.didProgress(progress)
        }
    }
}

func fetch(
    from sourceURL: URL,
    saveTo storageLocation: URL,
    didProgress: @escaping (Progress) -> Void
) async throws -> Void {
    let delegate = FetchDelegate(didProgress)
    
    let (tmp, _) = try await URLSession.shared.download(
        from: sourceURL,
        delegate: delegate
    )
    
    try FileManager.default.moveItem(
        at: tmp,
        to: storageLocation
    )
}
