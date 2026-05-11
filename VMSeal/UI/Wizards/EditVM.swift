//
//  +---------------------------------------------------------+
//  | Copyright (c) 2026 Axel H. Karlsson and contributors.   |
//  |                                                         |
//  | This file is licenced under the BSD 3-clause licence;   |
//  | see the LICENSE file in the project's source directory. |
//  +---------------------------------------------------------+
//
//  EditVM.swift
//  VMSeal
//
//  Created by Axel H. Karlsson on 2026-05-11.
//

import SwiftUI

extension Wizard {
    struct EditVM: View {
        struct Submitted {
            var memory: Double
            var vCPUs: Double
        }
        
        let didCancel: () -> Void
        let didSubmit: (_: Submitted) -> Void
        
        @Binding var vm: VM?
        
        // The default value will be updated in `onAppear()`.
        @State private var submitted = Submitted(
            memory: 0,
            vCPUs: 0
        )
        
        var body: some View {
            VStack {
                Spacer()
                
                Text("Edit VM")
                    .font(.title)
                
                Form {
                    Slider(
                        value: $submitted.memory,
                        in: VM.Requirements.Memory.minimum...VM.Requirements.Memory.maximum,
                        step: VM.Requirements.Memory.maximum / 32
                    ) {
                        Text("Memory: ")
                        Text(
                            ByteUnit.HumanReadable.from(
                                submitted.memory,
                                in: .GiB
                            )
                        )
                    }.padding(.leading)
                    
                    Slider(
                        value: $submitted.vCPUs,
                        in: Double(VM.Requirements.CPU.minimum)...Double(VM.Requirements.CPU.maximum),
                        step: 1
                    ) {
                        Text("vCPUs: ")
                        Text(
                            "\(Int(submitted.vCPUs)) vCPU\(submitted.vCPUs > 1 ? "s" : "")"
                        )
                    }.padding(.leading)
                }.formStyle(.grouped)
                
                HStack {
                    Button("Cancel", role: .cancel, action: didCancel)
                    
                    Button("Submit", role: .maybeConfirmRole) {
                        didSubmit(submitted)
                    }.buttonStyle(.borderedProminent)
                }
            }.onAppear {
                submitted.memory = vm?.memory ?? 0
                submitted.vCPUs = vm?.vCPUs ?? 0
            }
            .padding(.all)
        }
    }
}
