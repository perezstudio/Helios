//
//  MainWindowContent.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//


import SwiftUI
import SwiftData

struct MainWindowContent: View {
    let workspace: Workspace?
    @Binding var selectedTab: Tab?
    
    var body: some View {
        Group {
            if let workspace = workspace {
                TabView(
                    workspace: workspace,
                    selectedTab: $selectedTab
                )
            } else {
                EmptyStateView(
                    workspace: nil,
                    onCreateTab: {}
                )
            }
        }
    }
}
