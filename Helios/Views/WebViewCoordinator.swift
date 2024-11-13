//
//  WebViewCoordinator.swift
//  Helios
//
//  Created by Kevin Perez on 11/10/24.
//

import SwiftUI
import SwiftData
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
	var tabID: UUID
	let modelContext: ModelContext
	private let coordinatorID = UUID()
	
	private weak var currentWebView: WKWebView?
	private var isActive = true
	private var currentNavigation: WKNavigation?
	
	private var canGoBackObservation: NSKeyValueObservation?
	private var canGoForwardObservation: NSKeyValueObservation?
	private var urlObservation: NSKeyValueObservation?
	
	init(_ parent: WebViewContainer) {
		self.tabID = parent.tab.id
		self.modelContext = parent.modelContext
		super.init()
		print("Coordinator initialized: \(coordinatorID) for tab: \(tabID)")
	}
	
	func getTab() -> Tab? {
		if Thread.isMainThread {
			return fetchTab()
		}
		var result: Tab?
		DispatchQueue.main.sync {
			result = fetchTab()
		}
		return result
	}
	
	private func fetchTab() -> Tab? {
		assert(Thread.isMainThread)
		let targetID = self.tabID
		let descriptor = FetchDescriptor<Tab>(
			predicate: #Predicate<Tab> { $0.id == targetID }
		)
		return try? modelContext.fetch(descriptor).first
	}
	
	private func isMyWebView(_ webView: WKWebView) -> Bool {
		guard isActive,
			  webView === currentWebView,
			  webView.associatedCoordinatorID == coordinatorID else {
			if !isActive {
				print("[\(coordinatorID)] Coordinator is not active for tab: \(tabID)")
			}
			if webView !== currentWebView {
				print("[\(coordinatorID)] WebView reference mismatch for tab: \(tabID)")
			}
			if webView.associatedCoordinatorID != coordinatorID {
				print("[\(coordinatorID)] Coordinator ID mismatch for tab: \(tabID)")
			}
			return false
		}
		return true
	}
	
	private func clearObservations() {
		canGoBackObservation?.invalidate()
		canGoForwardObservation?.invalidate()
		urlObservation?.invalidate()
		
		canGoBackObservation = nil
		canGoForwardObservation = nil
		urlObservation = nil
	}
	
	private func observeNavigationState(_ webView: WKWebView) {
		print("[\(coordinatorID)] Setting up navigation state observations for tab: \(tabID)")
		
		canGoBackObservation = webView.observe(\.canGoBack) { [weak self] webView, _ in
			guard let self = self,
				  self.isMyWebView(webView) else {
				return
			}
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID else { return }
				print("[\(self.coordinatorID)] Updating canGoBack state for tab: \(self.tabID)")
				NotificationCenter.default.post(
					name: .webViewCanGoBackChanged,
					object: (self.tabID, webView.canGoBack)
				)
			}
		}
		
		canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] webView, _ in
			guard let self = self,
				  self.isMyWebView(webView) else {
				return
			}
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID else { return }
				print("[\(self.coordinatorID)] Updating canGoForward state for tab: \(self.tabID)")
				NotificationCenter.default.post(
					name: .webViewCanGoForwardChanged,
					object: (self.tabID, webView.canGoForward)
				)
			}
		}
		
		urlObservation = webView.observe(\.url) { [weak self] webView, _ in
			guard let self = self,
				  self.isMyWebView(webView),
				  let url = webView.url else {
				return
			}
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID,
					  let tab = self.getTab() else { return }
				print("[\(self.coordinatorID)] Updating URL state for tab: \(self.tabID) to: \(url)")
				
				tab.url = url
				NotificationCenter.default.post(
					name: .webViewURLChanged,
					object: WebViewURLChange(tab: tab, url: url)
				)
				try? self.modelContext.save()
			}
		}
	}
	
	func setCurrentWebView(_ webView: WKWebView) {
		assert(Thread.isMainThread, "setCurrentWebView must be called on main thread")
		
		// Only clear if the new WebView is different
		if webView !== currentWebView {
			clearWebView()
		}
		
		print("[\(coordinatorID)] Setting WebView for tab: \(tabID)")
		
		// Store coordinator ID using associated object
		webView.associatedCoordinatorID = coordinatorID
		currentWebView = webView
		isActive = true
		
		observeNavigationState(webView)
	}
	
	func clearWebView() {
		assert(Thread.isMainThread, "clearWebView must be called on main thread")
		
		print("[\(coordinatorID)] Clearing WebView for tab: \(tabID)")
		clearObservations()
		
		if let webView = currentWebView {
			// Only clear if it matches our coordinator ID
			if webView.associatedCoordinatorID == coordinatorID {
				webView.associatedCoordinatorID = nil
			}
		}
		
		currentWebView = nil
		isActive = false
		currentNavigation = nil
	}
	
	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		guard isMyWebView(webView) else {
			print("[\(coordinatorID)] Ignoring provisional navigation for non-matching WebView. Tab: \(tabID)")
			return
		}
		
		currentNavigation = navigation
		
		DispatchQueue.main.async { [weak self] in
			guard let self = self,
				  let tab = self.getTab() else { return }
			
			print("[\(self.coordinatorID)] Started loading for tab: \(self.tabID)")
			NotificationCenter.default.post(
				name: .webViewStartedLoading,
				object: tab
			)
		}
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard isMyWebView(webView),
			  navigation === currentNavigation else {
			print("[\(coordinatorID)] Ignoring finished navigation for non-matching WebView/Navigation. Tab: \(tabID)")
			return
		}
		
		DispatchQueue.main.async { [weak self] in
			guard let self = self,
				  let tab = self.getTab() else { return }
			
			print("[\(self.coordinatorID)] Finished loading for tab: \(self.tabID)")
			
			guard webView.associatedCoordinatorID == self.coordinatorID else {
				print("[\(self.coordinatorID)] WebView now belongs to different coordinator")
				return
			}
			
			NotificationCenter.default.post(
				name: .webViewFinishedLoading,
				object: tab
			)
			
			if let url = webView.url {
				tab.url = url
				NotificationCenter.default.post(
					name: .webViewURLChanged,
					object: WebViewURLChange(tab: tab, url: url)
				)
			}
			
			self.currentNavigation = nil
			self.updateTitleAndFavicon(webView: webView, tab: tab)
		}
	}
	
	private func updateTitleAndFavicon(webView: WKWebView, tab: Tab) {
		guard isMyWebView(webView), tab.id == self.tabID else {
			print("[\(coordinatorID)] Attempting to update title and favicon for non-matching WebView or Tab. Tab: \(tabID)")
			return
		}
		
		webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
			guard let self = self,
				  self.isMyWebView(webView),
				  let title = result as? String else { return }
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID,
					  let currentTab = self.getTab(),
					  currentTab.id == self.tabID else { return }
				print("[\(self.coordinatorID)] Updating title for tab: \(self.tabID) to: \(title)")
				currentTab.title = title
				try? self.modelContext.save()
			}
		}
		
		webView.evaluateJavaScript("""
   var link = document.querySelector("link[rel~='icon']");
   if (!link) {
  link = document.querySelector("link[rel~='shortcut icon']");
   }
   link ? link.href : null;
  """) { [weak self] (result, error) in
			guard let self = self,
				  self.isMyWebView(webView),
				  let iconURLString = result as? String,
				  let iconURL = URL(string: iconURLString) else { return }
			
			print("[\(self.coordinatorID)] Found favicon for tab: \(self.tabID) at URL: \(iconURL)")
			self.downloadFavicon(from: iconURL, webView: webView, tab: tab)
		}
	}
	
	private func downloadFavicon(from url: URL, webView: WKWebView, tab: Tab) {
		URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self,
				  let data = data else { return }
			
			DispatchQueue.main.async {
				guard self.isMyWebView(webView),
					  webView.associatedCoordinatorID == self.coordinatorID,
					  let currentTab = self.getTab(),
					  currentTab.id == self.tabID else { return }
				
				print("[\(self.coordinatorID)] Updating favicon for tab: \(self.tabID)")
				currentTab.favicon = data
				try? self.modelContext.save()
			}
		}.resume()
	}
	
	deinit {
		print("[\(coordinatorID)] Coordinator deinit for tab: \(tabID)")
		clearWebView()
	}
}
