//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  SheetView.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-11-21.
//

import Foundation
import SwiftUI

protocol SheetWizard {
    associatedtype Submission
    
    var title: String { get }
    
    var didCancel: () -> Void { get }
    var didSubmit: (_: Submission) -> Void { get }
}

struct NewVMSheetView: SheetWizard, View {
    typealias Submission = VM.Configuration
    
    @State private var submission: Submission = VM.Configuration.defaults
    
    let title = "New VM"
    
    let didCancel: () -> Void
    let didSubmit: (_: Submission) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(self.title)
                .font(.title)
            
            Form {
                Text("Info")
                    .font(.title2)
                
                Grid {
                    GridRow {
                        TextField(text: self.$submission.name) {
                            Text("Name: ")
                        }
                        .textFieldStyle(.squareBorder)
                        .padding(.leading)
                    }
                }
                
                Text("Hardware")
                    .font(.title2)
                
                Slider(
                    value: self.$submission.memoryInBytes,
                    in: VM.Requirements.Memory.minimum...VM.Requirements.Memory.maximum,
                    step: VM.Requirements.Memory.maximum / 32
                ) {
                    Text("Memory: ")
                    Text(
                        ByteUnit.HumanReadable.from(
                            self.submission.memoryInBytes,
                            in: .GiB
                        )
                    )
                }.padding(.leading)
                
                Slider(
                    value: self.$submission.diskSizeInBytes,
                    in: VM.Requirements.DiskSize.minimum...VM.Requirements.DiskSize.maximum,
                    step: VM.Requirements.DiskSize.maximum / 16
                ) {
                    Text("Disk Size: ")
                    Text(
                        ByteUnit.HumanReadable.from(
                            self.submission.diskSizeInBytes,
                            in: .GiB
                        )
                    )
                }.padding(.leading)
                
                Slider(
                    value: Binding<Double>(
                        get: {
                            Double(self.submission.vCPUs)
                        },
                        set: { newValue in
                            self.submission.vCPUs = Int(newValue)
                        }
                    ),
                    in: Double(VM.Requirements.CPU.minimum)...Double(VM.Requirements.CPU.maximum),
                    step: 1
                ) {
                    Text("vCPUs: ")
                    Text(
                        "\(Int(self.submission.vCPUs)) vCPU\(self.submission.vCPUs > 1 ? "s" : "")"
                    )
                }.padding(.leading)
            }.formStyle(.grouped)
            
            HStack {
                Button("Cancel", role: .cancel, action: self.didCancel)
                
                Button("Create", role: .maybeConfirmRole) {
                    self.didSubmit(self.submission)
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.submission.name.isEmpty)
            }
        }
        .padding(.all)
    }
}

struct EditVMSheetView: SheetWizard, View {
    struct EditSubmission {
        var vCPUs: Int
        var memory: Double
        var newName: String
    }
    
    typealias Submission = EditSubmission
    
    @State private var submission: Submission
    
    let title = "Edit VM"
    
    let didCancel: () -> Void
    let didSubmit: (_: Submission) -> Void
    
    init(previous: EditSubmission, didCancel: @escaping () -> Void, didSubmit: @escaping (_: Submission) -> Void) {
        self.submission = previous
        
        self.didCancel = didCancel
        self.didSubmit = didSubmit
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(self.title)
                .font(.title)
            
            Form {
                Grid {
                    GridRow {
                        TextField(text: self.$submission.newName) {
                            Text("Name: ")
                        }
                        .textFieldStyle(.squareBorder)
                        .padding(.leading)
                    }
                }
                
                Slider(
                    value: self.$submission.memory,
                    in: VM.Requirements.Memory.minimum...VM.Requirements.Memory.maximum,
                    step: VM.Requirements.Memory.maximum / 32
                ) {
                    Text("Memory: ")
                    Text(
                        ByteUnit.HumanReadable.from(
                            self.submission.memory,
                            in: .GiB
                        )
                    )
                }.padding(.leading)
                
                Slider(
                    value: Binding<Double>(
                        get: {
                            Double(self.submission.vCPUs)
                        },
                        set: { newValue in
                            self.submission.vCPUs = Int(newValue)
                        }
                    ),
                    in: Double(VM.Requirements.CPU.minimum)...Double(VM.Requirements.CPU.maximum),
                    step: 1
                ) {
                    Text("vCPUs: ")
                    Text(
                        "\(Int(self.submission.vCPUs)) vCPU\(self.submission.vCPUs > 1 ? "s" : "")"
                    )
                }.padding(.leading)
            }.formStyle(.grouped)
            
            HStack {
                Button("Cancel", role: .cancel, action: self.didCancel)
                
                Button("Submit", role: .maybeConfirmRole) {
                    self.didSubmit(self.submission)
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(.all)
    }
}
