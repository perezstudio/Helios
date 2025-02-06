//
//  SidebarView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import WebKit

struct SidebarView: View {
	let windowId: UUID
	@Environment(\.modelContext) var modelContext
	@Bindable var viewModel: BrowserViewModel
	@State private var showWorkspaceSheet = false
	@State private var editingWorkspace: Workspace?
	@FocusState private var isUrlBarFocused: Bool
	@State private var currentWorkspace: Workspace? = nil
	@State private var selectedWorkspace: Workspace?
	
	var body: some View {
		VStack {
			// URL Bar
			TextField("Enter URL or search", text: $viewModel.urlInput, onCommit: {
				Task {
					await viewModel.handleUrlInput()
				}
			})
			.textFieldStyle(.roundedBorder)
			.padding(.horizontal)
			.padding(.top)
			.focused($isUrlBarFocused)
			
			// Tabs List
			List(selection: Binding(
				get: { viewModel.getSelectedTab(for: windowId) },
				set: { viewModel.selectTab($0, for: windowId) }
			)) {
				Section(header: Text("Pinned Tabs")) {
					ForEach(viewModel.pinnedTabs, id: \.id) { tab in
						TabRow(tab: tab, windowId: windowId, viewModel: viewModel)
					}
				}
				Section(header: Text("Bookmark Tabs")) {
					ForEach(viewModel.bookmarkTabs, id: \.id) { tab in
						TabRow(tab: tab, windowId: windowId, viewModel: viewModel)
					}
				}
				Section(header: Text("Normal Tabs")) {
					ForEach(viewModel.normalTabs, id: \.id) { tab in
						TabRow(tab: tab, windowId: windowId, viewModel: viewModel)
					}
					Button(action: {
						Task {
							await viewModel.addNewTab()
						}
					}) {
						Label("New Tab", systemImage: "plus")
					}
				}
			}
			.listStyle(SidebarListStyle()) // Native macOS sidebar styling
			
			Divider()
			
			// Workspace Picker and Add Workspace Button
			HStack {
				if let workspace = currentWorkspace {
					Button(action: {
						editingWorkspace = workspace
						showWorkspaceSheet = true
					}) {
						Image(systemName: "pencil.circle")
					}
					.help("Edit Workspace")
				}
				
				if viewModel.workspaces.count <= 6 {
					Picker("", selection: $selectedWorkspace) {
						ForEach(viewModel.workspaces, id: \.id) { workspace in
							Label(workspace.name, systemImage: workspace.icon)
								.tag(Optional(workspace))
								.labelStyle(.iconOnly)
						}
					}
					.pickerStyle(.segmented)
					.onChange(of: selectedWorkspace) { newWorkspace in
						Task {
							await viewModel.setCurrentWorkspace(newWorkspace, for: windowId)
						}
					}
				} else {
					Picker("", selection: $selectedWorkspace) {
						ForEach(viewModel.workspaces, id: \.id) { workspace in
							Label(workspace.name, systemImage: workspace.icon)
								.tag(Optional(workspace))
						}
					}
					.pickerStyle(.menu)
					.onChange(of: selectedWorkspace) { newWorkspace in
						Task {
							await viewModel.setCurrentWorkspace(newWorkspace, for: windowId)
						}
					}
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
			.onAppear {
				Task {
					currentWorkspace = await viewModel.getCurrentWorkspace(for: windowId)
					selectedWorkspace = currentWorkspace
				}
			}
			.toolbar {
				ToolbarItemGroup(placement: .primaryAction) {
					Spacer()
					Button(action: {
						viewModel.goBack()
					}) {
						Image(systemName: "chevron.left")
					}
					.help("Go Back")
					
					Button(action: {
						viewModel.goForward()
					}) {
						Image(systemName: "chevron.right")
					}
					.help("Go Forward")
					
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
					viewModel: viewModel, isPresented: $showWorkspaceSheet,
					workspaceToEdit: editingWorkspace
				)
			}
		}
		.onChange(of: viewModel.urlBarFocused) { _, newValue in
			isUrlBarFocused = newValue
			if !newValue {
				viewModel.urlBarFocused = false
			}
		}
	}
}
