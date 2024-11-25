//
//  WorkspaceHeaderView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct WorkspaceHeaderView: View {
    let workspace: Workspace
    @Binding var showingProfileChangeSheet: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: workspace.iconName)
                    .font(.system(size: 16))
                Text(workspace.name)
                    .font(.headline)
            }
            
            Spacer()
            
            Menu {
                Button("Change Profile") {
                    showingProfileChangeSheet = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
