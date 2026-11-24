//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Viewport.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-22.
//


import SwiftUI
import Virtualization

fileprivate class ViewportNSView: VZVirtualMachineView {
    var vm: VM?
    
    // -- Disable the clunky virtual cursor --
    
    override func mouseEntered(with event: NSEvent) {
        self.becomeFirstResponder()
        
        DispatchQueue.main.async {
            unsafe self.window?.makeFirstResponder(self)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        self.resignFirstResponder()
        
        DispatchQueue.main.async {
            unsafe self.window?.resignFirstResponder()
        }
    }
}

struct ViewportRepresentable: NSViewRepresentable {
    var currentVM: VM
    
    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = ViewportNSView()
        view.vm = currentVM
        
        view.virtualMachine = currentVM.vz.vzVirtualMachine
        
        view.becomeFirstResponder()
        view.automaticallyReconfiguresDisplay = true
        
        if let bounds = currentVM.displaySize {
            view.setBoundsSize(bounds)
        }
        
        DispatchQueue.main.async {
            unsafe view.window?.makeFirstResponder(view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) -> Void {
        if nsView.virtualMachine !== currentVM.vz.vzVirtualMachine {
            nsView.virtualMachine = currentVM.vz.vzVirtualMachine
        }
    }
    
    typealias NSViewType = VZVirtualMachineView
}
