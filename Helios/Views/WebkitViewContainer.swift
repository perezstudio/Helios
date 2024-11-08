//
//  WebkitViewContainer.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import WebKit

// MARK: - WebView Container
struct WebViewContainer: NSViewRepresentable {
	let tab: Tab
	@Environment(\.modelContext) private var modelContext
	
	func makeNSView(context: Context) -> WKWebView {
		let config = WKWebViewConfiguration()
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.navigationDelegate = context.coordinator
		webView.uiDelegate = context.coordinator
		
		// Store the webView reference
		WebViewStore.shared.store(webView, for: tab.id)
		
		// Observe navigation state
		context.coordinator.observeNavigationState(webView)
		
		return webView
	}
	
	func updateNSView(_ webView: WKWebView, context: Context) {
		// Check if the URL has changed or if lastVisited was updated (refresh)
		let currentURL = webView.url
		let shouldReload = currentURL != tab.url ||
						  context.coordinator.lastLoadedDate != tab.lastVisited
		
		if shouldReload {
			let request = URLRequest(url: tab.url)
			webView.load(request)
			context.coordinator.lastLoadedDate = tab.lastVisited
			
			NotificationCenter.default.post(
				name: .webViewStartedLoading,
				object: tab
			)
		}
	}
	
	static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
		// Remove stored reference when view is destroyed
		WebViewStore.shared.remove(for: coordinator.parent.tab.id)
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
		var parent: WebViewContainer
		var lastLoadedDate: Date?
		private var canGoBackObservation: NSKeyValueObservation?
		private var canGoForwardObservation: NSKeyValueObservation?
		
		init(_ parent: WebViewContainer) {
			self.parent = parent
			super.init()
		}
		
		func observeNavigationState(_ webView: WKWebView) {
			// Observe canGoBack changes
			canGoBackObservation = webView.observe(\.canGoBack) { [weak self] webView, _ in
				guard let self = self else { return }
				NotificationCenter.default.post(
					name: .webViewCanGoBackChanged,
					object: (self.parent.tab.id, webView.canGoBack)
				)
			}
			
			// Observe canGoForward changes
			canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] webView, _ in
				guard let self = self else { return }
				NotificationCenter.default.post(
					name: .webViewCanGoForwardChanged,
					object: (self.parent.tab.id, webView.canGoForward)
				)
			}
		}
		
		func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
			NotificationCenter.default.post(
				name: .webViewStartedLoading,
				object: parent.tab
			)
		}
		
		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			NotificationCenter.default.post(
				name: .webViewFinishedLoading,
				object: parent.tab
			)
			
			// Update URL if it changed
			if let url = webView.url {
				DispatchQueue.main.async {
					self.parent.tab.url = url
					try? self.parent.modelContext.save()
				}
			}
			
			// Update tab title
			webView.evaluateJavaScript("document.title") { (result, error) in
				if let title = result as? String {
					DispatchQueue.main.async {
						self.parent.tab.title = title
						try? self.parent.modelContext.save()
					}
				}
			}
			
			// Get favicon
			webView.evaluateJavaScript("""
				var link = document.querySelector("link[rel~='icon']");
				if (!link) {
					link = document.querySelector("link[rel~='shortcut icon']");
				}
				link ? link.href : null;
			""") { (result, error) in
				if let iconURLString = result as? String,
				   let iconURL = URL(string: iconURLString) {
					self.downloadFavicon(from: iconURL)
				}
			}
		}
		
		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
			// Handle navigation policy
			if navigationAction.targetFrame == nil {
				// Handle links that would open in new window/tab
				webView.load(navigationAction.request)
				decisionHandler(.cancel)
				return
			}
			decisionHandler(.allow)
		}
		
		private func downloadFavicon(from url: URL) {
			URLSession.shared.dataTask(with: url) { data, response, error in
				if let data = data {
					DispatchQueue.main.async {
						self.parent.tab.favicon = data
						try? self.parent.modelContext.save()
					}
				}
			}.resume()
		}
		
		deinit {
			canGoBackObservation?.invalidate()
			canGoForwardObservation?.invalidate()
		}
	}
}

// MARK: - URL Extension for Validation
extension URL {
	var isValid: Bool {
		guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
			return false
		}
		if let match = detector.firstMatch(in: self.absoluteString, options: [], range: NSRange(location: 0, length: self.absoluteString.utf16.count)) {
			return match.range.length == self.absoluteString.utf16.count
		}
		return false
	}
}

// MARK: - WebView Store
class WebViewStore {
	static let shared = WebViewStore()
	private var webViews: [UUID: WKWebView] = [:]
	
	func store(_ webView: WKWebView, for tabID: UUID) {
		webViews[tabID] = webView
	}
	
	func remove(for tabID: UUID) {
		webViews.removeValue(forKey: tabID)
	}
	
	func goBack(for tabID: UUID) {
		webViews[tabID]?.goBack()
	}
	
	func goForward(for tabID: UUID) {
		webViews[tabID]?.goForward()
	}
	
	func stopLoading(for tabID: UUID) {
		webViews[tabID]?.stopLoading()
	}
}

// MARK: - Additional Notification Names
extension Notification.Name {
	static let webViewCanGoBackChanged = Notification.Name("webViewCanGoBackChanged")
	static let webViewCanGoForwardChanged = Notification.Name("webViewCanGoForwardChanged")
}
