//
//  SidebarView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import WebKit

struct SidebarView: View {
	@Environment(\.modelContext) var modelContext
	@EnvironmentObject var viewModel: BrowserViewModel
	@State private var showWorkspaceSheet = false
	@State private var editingWorkspace: Workspace?

	var body: some View {
		VStack {
			// URL Bar
			TextField("Enter URL or search", text: $viewModel.urlInput, onCommit: {
				viewModel.handleUrlInput()
			})
			.textFieldStyle(.roundedBorder)
			.padding(.horizontal)
			.padding(.top)

			// Tabs List
			List(selection: $viewModel.currentTab) {
				Section(header: Text("Pinned Tabs")) {
					ForEach(viewModel.pinnedTabs, id: \.id) { tab in
						TabRow(tab: tab)
					}
				}
				Section(header: Text("Bookmark Tabs")) {
					ForEach(viewModel.bookmarkTabs, id: \.id) { tab in
						TabRow(tab: tab)
					}
				}
				Section(header: Text("Normal Tabs")) {
					ForEach(viewModel.normalTabs, id: \.id) { tab in
						TabRow(tab: tab)
					}
					Button(action: {
						viewModel.addNewTab()
					}) {
						Label("New Tab", systemImage: "plus")
					}
				}
			}
			.listStyle(SidebarListStyle()) // Native macOS sidebar styling

			Divider()

			// Workspace Picker and Add Workspace Button
			HStack {
				if viewModel.currentWorkspace != nil {
					Button(action: {
						editingWorkspace = viewModel.currentWorkspace
						showWorkspaceSheet = true
					}) {
						Image(systemName: "pencil.circle")
					}
					.help("Edit Workspace")
				}
				if(viewModel.workspaces.count <= 6) {
					Picker("", selection: $viewModel.currentWorkspace) {
						ForEach(viewModel.workspaces, id: \.id) { workspace in
							Label(workspace.name, systemImage: workspace.icon).tag(workspace)
								.labelStyle(.iconOnly)
						}
					}
					.pickerStyle(.segmented)
				} else {
					Picker("", selection: $viewModel.currentWorkspace) {
						ForEach(viewModel.workspaces, id: \.id) { workspace in
							Label(workspace.name, systemImage: workspace.icon).tag(workspace)
						}
					}
					.pickerStyle(.menu)
				}

				Button(action: {
					editingWorkspace = nil
					showWorkspaceSheet = true
				}) {
					Image(systemName: "plus.circle")
				}
				.help("Add Workspace")
			}
			.padding(.horizontal, 4)
			.padding(.vertical, 4)
			.padding(.bottom, 4)
			.toolbar {
				ToolbarItemGroup(placement: .primaryAction) {
					Spacer()
					Button(action: {
						viewModel.goBack()
					}) {
						Image(systemName: "chevron.left")
					}
					.help("Go Back")
//					.disabled(!viewModel.canGoBack)

					Button(action: {
						viewModel.goForward()
					}) {
						Image(systemName: "chevron.right")
					}
					.help("Go Forward")
//					.disabled(!viewModel.canGoForward)

					Button(action: {
						viewModel.refresh()
					}) {
						Image(systemName: "arrow.clockwise")
					}
					.help("Refresh")
				}
			}
			.sheet(isPresented: $showWorkspaceSheet) {
				CreateWorkspaceView(
					isPresented: $showWorkspaceSheet,
					workspaceToEdit: editingWorkspace
				)
			}
		}
	}
}
