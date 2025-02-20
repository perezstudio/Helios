//
//  PermissionRequestView.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//


import SwiftUI
import SwiftData

struct PermissionRequestView: View {
    @Environment(\.modelContext) private var modelContext
    let request: PermissionManager.PermissionRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.blue)
                Text("Permission Request")
                    .font(.headline)
            }
            
            Text("\(request.domain) is requesting access to \(request.permission.rawValue.lowercased())")
                .font(.body)
            
            HStack(spacing: 12) {
                Button("Allow") {
                    PermissionManager.shared.handlePermissionResponse(.allow, 
                                                                    for: request,
                                                                    in: modelContext)
                }
                .keyboardShortcut(.return)
                
                Button("Block") {
                    PermissionManager.shared.handlePermissionResponse(.block,
                                                                    for: request,
                                                                    in: modelContext)
                }
                .keyboardShortcut(.escape)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

// Helper view to manage the display of permission requests
struct PermissionRequestContainer: View {
    @Bindable var permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if let activeRequest = permissionManager.activeRequest {
                PermissionRequestView(request: activeRequest)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 300)
        .animation(.spring(), value: permissionManager.activeRequest)
    }
}
