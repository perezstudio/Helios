//
//  AddSearchEngineView.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//

import SwiftUI
import SwiftData

struct AddSearchEngineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var shortcut = ""
    @State private var searchUrl = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Shortcut", text: $shortcut)
                    .textCase(.lowercase)
                TextField("Search URL", text: $searchUrl)
                    .textCase(.lowercase)
                
                Text("Use %s to indicate where the search terms should be inserted in the URL")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .formStyle(.grouped)
            .navigationTitle("Add Search Engine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSearchEngine()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(width: 400, height: 300)
        .alert("Invalid Search Engine", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && 
        !shortcut.isEmpty && 
        !searchUrl.isEmpty && 
        searchUrl.contains("%s")
    }
    
    private func addSearchEngine() {
        guard isValid else {
            errorMessage = "Please fill in all fields and ensure the URL contains %s"
            showError = true
            return
        }
        
        let engine = SearchEngine(
            name: name,
            shortcut: shortcut,
            searchUrl: searchUrl
        )
        
        modelContext.insert(engine)
        try? modelContext.save()
        dismiss()
    }
}
