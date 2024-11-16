//
//  WebViewCoordinator.swift
//  Helios
//
//  Created by Kevin Perez on 11/10/24.
//

import SwiftUI
import SwiftData
@preconcurrency import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
	var tabID: UUID
	let modelContext: ModelContext
	private let coordinatorID = UUID()
	private weak var currentWebView: WKWebView?
	
	init(_ parent: WebViewContainer) {
		self.tabID = parent.tab.id
		self.modelContext = parent.modelContext
		super.init()
	}
	
	// Handle link clicks uniformly
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if navigationAction.navigationType == .linkActivated {
			if let url = navigationAction.request.url,
			   let tab = getTab() {
				// Get proper destination workspace
				let destinationWorkspace: Workspace
				if tab.isPinned {
					// For pinned tabs, use the current workspace
					if let workspace = tab.workspace?.profile?.workspaces.first {
						destinationWorkspace = workspace
					} else {
						decisionHandler(.allow)
						return
					}
				} else {
					// For regular tabs, use their workspace
					if let workspace = tab.workspace {
						destinationWorkspace = workspace
					} else {
						decisionHandler(.allow)
						return
					}
				}
				
				// Create new tab in appropriate workspace
				let newTab = Tab(title: url.host ?? "New Tab", url: url)
				destinationWorkspace.tabs.append(newTab)
				try? modelContext.save()
				
				// Notify about new tab
				NotificationCenter.default.post(
					name: .newTabCreated,
					object: newTab
				)
				
				decisionHandler(.cancel)
				return
			}
		}
		decisionHandler(.allow)
	}
	
	// Handle page title updates for favicon
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		updateFavicon(webView)
		updateTitle(webView)
	}
	
	private func updateFavicon(_ webView: WKWebView) {
		webView.evaluateJavaScript("""
			var link = document.querySelector("link[rel~='icon']");
			if (!link) {
				link = document.querySelector("link[rel~='shortcut icon']");
			}
			link ? link.href : null;
		""") { [weak self] (result, error) in
			guard let self = self,
				  let iconURLString = result as? String,
				  let iconURL = URL(string: iconURLString) else { return }
			
			URLSession.shared.dataTask(with: iconURL) { [weak self] data, response, error in
				guard let self = self,
					  let data = data,
					  let tab = self.getTab() else { return }
				
				DispatchQueue.main.async {
					tab.favicon = data
					try? self.modelContext.save()
				}
			}.resume()
		}
	}
	
	private func updateTitle(_ webView: WKWebView) {
		webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
			guard let self = self,
				  let title = result as? String,
				  let tab = self.getTab() else { return }
			
			DispatchQueue.main.async {
				tab.title = title
				try? self.modelContext.save()
			}
		}
	}
	
	private func getTab() -> Tab? {
		let descriptor = FetchDescriptor<Tab>(
			predicate: #Predicate<Tab> { tab in
				tab.id == tabID
			}
		)
		return try? modelContext.fetch(descriptor).first
	}
}

// Add new notification for tab creation
extension Notification.Name {
	static let newTabCreated = Notification.Name("newTabCreated")
}
