//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  Detail.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-03-23.
//

import SwiftUI
import Virtualization

private struct Overlay {
    struct Stopped: View {
        var body: some View {
            HStack {
                Image(systemName: "pause.circle")
                
                Spacer()
                    .frame(width: 10)
                
                Text("Stopped")
                    .bold()
            }
            .font(.largeTitle)
            .foregroundStyle(.white)
        }
    }
    
    struct Starting: View {
        var body: some View {
            VStack {
                ProgressView()
                
                Spacer()
                    .frame(height: 10)
                
                Text("Starting...")
                    .bold()
            }
            .font(.largeTitle)
            .foregroundStyle(.white)
        }
    }
}

private struct Detail {
    let selectedVM: VM?
    let selection: Set<VM.ID>
    
    var unselected: some View {
        Notice(title: "No VM selected.")
    }
    
    var multipleSelected: some View {
        Notice(
            title: "\(selection.count) VMs are selected."
        )
    }
    
    var empty: some View {
        Notice(
            title: "You don't have any VMs, yet...",
            subtitle: "Create one via 'File > New VM...' in the menubar."
        )
    }
    
    var vm: some View {
        HStack {
            if selectedVM != nil {
                ZStack {
                    VM.UI.Frame(currentVM: selectedVM!)
                        .id(selectedVM!.id) // setting ID prevents a bug where old artifacts show up on shutdown VMs.
                    
                    if selectedVM!.state == .stopped {
                        Overlay.Stopped()
                    }
                    
                    if selectedVM!.state == .starting {
                        Overlay.Starting()
                    }
                }
            } else {
                Text("Something went wrong displaying the VM...")
            }
        }
        .navigationTitle(selectedVM?.name ?? "Unnamed VM")
    }
}
    
extension Dashboard {
    @ViewBuilder var detail: some View {
        let d = Detail(
            selectedVM: self.selectedVM,
            selection: self.selection
        )
        
        if vms.isEmpty {
            d.empty
        } else if selection.isEmpty {
            d.unselected
        } else if selection.count > 1 {
            d.multipleSelected
        } else {
            d.vm
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
