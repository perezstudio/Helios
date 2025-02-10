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
	@State private var showUrlBarSheet: Bool = false
	
	var body: some View {
		VStack {
			
			// URL Bar
			URLBarView(
				viewModel: viewModel,
				windowId: windowId,
				currentTab: viewModel.getSelectedTab(for: windowId),
				isSheet: false
			)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			
			// Tabs List
			List(selection: Binding(
				get: { viewModel.getSelectedTab(for: windowId) },
				set: { viewModel.selectTab($0, for: windowId) }
			)) {
				DraggableTabSection(
					title: "Pinned Tabs",
					tabs: viewModel.pinnedTabs,
					tabType: .pinned,
					windowId: windowId,
					viewModel: viewModel
				)
				
				if let currentWorkspace = viewModel.currentWorkspace {
					Section {
						HStack {
							HStack {
								Image(systemName: currentWorkspace.icon)
								Text(currentWorkspace.name)
							}
							Spacer()
							Button(action: {
								editingWorkspace = currentWorkspace
								showWorkspaceSheet = true
							}) {
								Image(systemName: "pencil.circle")
							}
							.help("Edit Workspace")
						}
					}
				}
				
				DraggableTabSection(
					title: "Bookmark Tabs",
					tabs: viewModel.bookmarkTabs,
					tabType: .bookmark,
					windowId: windowId,
					viewModel: viewModel
				)
				
				DraggableTabSection(
					title: "Normal Tabs",
					tabs: viewModel.normalTabs,
					tabType: .normal,
					windowId: windowId,
					viewModel: viewModel
				)
				
				Button(action: {
					showUrlBarSheet = true
				}) {
					Label("New Tab", systemImage: "plus")
				}
				.keyboardShortcut("t", modifiers: [.command])
			}
			.listStyle(SidebarListStyle()) // Native macOS sidebar styling
			
			Divider()
			
			// Workspace Picker and Add Workspace Button
			HStack {
				
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
					.keyboardShortcut("r", modifiers: [.command])
				}
			}
			.sheet(isPresented: $showWorkspaceSheet) {
				CreateWorkspaceView(
					viewModel: viewModel, isPresented: $showWorkspaceSheet,
					workspaceToEdit: editingWorkspace
				)
			}
			.sheet(isPresented: $showUrlBarSheet) {
				URLBarView(viewModel: viewModel, windowId: windowId, isSheet: true)
					.presentationDetents([.height(140)])
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
