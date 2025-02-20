//
//  AddSitePatternSheet.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

struct AddSitePatternSheet: View {
    let url: URL
    @Binding var pattern: String
    let onAdd: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Site Pattern", text: $pattern)
                } footer: {
                    Text("You can use patterns like *.example.com to match all subdomains")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Site Pattern")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(pattern)
                        dismiss()
                    }
                    .disabled(pattern.isEmpty)
                }
            }
        }
        .onAppear {
            if let host = url.host {
                pattern = host
            }
        }
    }
}
