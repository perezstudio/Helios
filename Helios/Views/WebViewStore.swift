//
//  WebViewStore.swift
//  Helios
//
//  Created by Kevin Perez on 11/10/24.
//

import SwiftUI
import SwiftData
import WebKit

class WebViewStore {
	static let shared = WebViewStore()
	private var webViews: [UUID: WKWebView] = [:]
	private var activeTabId: UUID?
	private var coordinators: [UUID: WebViewCoordinator] = [:]
	private let storeQueue = DispatchQueue(label: "com.helios.webview.store")
	private let queueKey = DispatchSpecificKey<Bool>()
	
	private init() {
		storeQueue.setSpecific(key: queueKey, value: true)
	}
	
	func setActiveTab(_ tabId: UUID?) {
		synchronize {
			self.activeTabId = tabId
			
			// Hide all inactive WebViews
			webViews.forEach { (id, webView) in
				webView.isHidden = id != tabId
			}
		}
	}
	
	func getCurrentWebView(for tabId: UUID) -> WKWebView? {
		return synchronize {
			return webViews[tabId]
		}
	}
	
	func getOrCreateWebView(for tabId: UUID, createWebView: () -> WKWebView) -> WKWebView {
		return synchronize {
			if let existingWebView = webViews[tabId] {
				existingWebView.isHidden = activeTabId != tabId
				return existingWebView
			}
			
			let newWebView = createWebView()
			webViews[tabId] = newWebView
			newWebView.isHidden = activeTabId != tabId
			return newWebView
		}
	}
	
	func remove(for tabId: UUID) {
		synchronize {
			if let webView = webViews.removeValue(forKey: tabId) {
				webView.stopLoading()
				webView.navigationDelegate = nil
				webView.uiDelegate = nil
				webView.removeFromSuperview()
			}
			coordinators.removeValue(forKey: tabId)
		}
	}
	
	func removeAll() {
		synchronize {
			webViews.forEach { (_, webView) in
				webView.stopLoading()
				webView.navigationDelegate = nil
				webView.uiDelegate = nil
				webView.removeFromSuperview()
			}
			webViews.removeAll()
			coordinators.removeAll()
		}
	}
	
	// Navigation methods
	func goBack(for tabId: UUID) {
		if let webView = getCurrentWebView(for: tabId) {
			webView.goBack()
		}
	}
	
	func goForward(for tabId: UUID) {
		if let webView = getCurrentWebView(for: tabId) {
			webView.goForward()
		}
	}
	
	func reload(for tabId: UUID) {
		if let webView = getCurrentWebView(for: tabId) {
			webView.reload()
		}
	}
	
	func stopLoading(for tabId: UUID) {
		if let webView = getCurrentWebView(for: tabId) {
			webView.stopLoading()
		}
	}
	
	private func synchronize<T>(_ block: () -> T) -> T {
		if DispatchQueue.getSpecific(key: queueKey) == true {
			return block()
		} else {
			return storeQueue.sync(execute: block)
		}
	}
}
