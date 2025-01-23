//
//  SearchEngineSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//

import SwiftUI
import SwiftData

struct SearchEngineSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var searchEngines: [SearchEngine]
    @State private var showAddSheet = false
    @State private var engineToDelete: SearchEngine?
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search engines can be accessed quickly by typing their shortcut followed by a space in the address bar.")
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Table(searchEngines) {
                TableColumn("Name", value: \.name)
                TableColumn("Shortcut") { engine in
                    Text(engine.shortcut)
                        .monospaced()
                }
                TableColumn("URL") { engine in
                    Text(engine.searchUrl)
                        .truncationMode(.middle)
                }
                TableColumn("") { engine in
                    if !engine.isBuiltIn {
                        Button(role: .destructive) {
                            engineToDelete = engine
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .width(30)
            }
            
            HStack {
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label("Add Search Engine", systemImage: "plus")
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .sheet(isPresented: $showAddSheet) {
            AddSearchEngineView()
        }
        .alert("Delete Search Engine", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let engine = engineToDelete {
                    deleteSearchEngine(engine)
                }
            }
        } message: {
            Text("Are you sure you want to delete this search engine?")
        }
        .navigationTitle("Search Engines")
    }
    
    private func deleteSearchEngine(_ engine: SearchEngine) {
        modelContext.delete(engine)
        try? modelContext.save()
    }
}
