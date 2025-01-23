//
//  WindowManager.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//


import SwiftUI
import Combine

class WindowManager: ObservableObject {
	static let shared = WindowManager()
	
	@Published var activeWindow: UUID?
	private var windows: Set<UUID> = []
	private var tabSelections: [UUID: UUID] = [:] // [WindowID: TabID]
	private var workspaceSelections: [UUID: UUID] = [:] // [WindowID: WorkspaceID]
	
	private init() {}
	
	func registerWindow(_ id: UUID) {
		windows.insert(id)
		if activeWindow == nil {
			activeWindow = id
		}
	}
	
	func unregisterWindow(_ id: UUID) {
		windows.remove(id)
		tabSelections.removeValue(forKey: id)
		workspaceSelections.removeValue(forKey: id)
		if activeWindow == id {
			activeWindow = windows.first
		}
	}
	
	func setActiveWindow(_ id: UUID) {
		activeWindow = id
	}
	
	func selectTab(_ tabId: UUID?, in windowId: UUID) {
		// Clear previous selection for this tab in other windows
		if let tabId = tabId {
			for (windowId, selectedTabId) in tabSelections {
				if selectedTabId == tabId {
					tabSelections[windowId] = nil
				}
			}
		}
		
		// Set new selection
		tabSelections[windowId] = tabId
	}
	
	func selectWorkspace(_ workspaceId: UUID?, in windowId: UUID) {
		workspaceSelections[windowId] = workspaceId
	}
	
	func getSelectedTab(for windowId: UUID) -> UUID? {
		return tabSelections[windowId]
	}
	
	func getSelectedWorkspace(for windowId: UUID) -> UUID? {
		return workspaceSelections[windowId]
	}
	
	func isTabSelectedInOtherWindow(_ tabId: UUID, currentWindow: UUID) -> Bool {
		for (windowId, selectedTabId) in tabSelections {
			if windowId != currentWindow && selectedTabId == tabId {
				return true
			}
		}
		return false
	}
}
