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
	private var loadingTabIDs: Set<UUID> = []
	private var lastURLs: [UUID: URL] = [:]
	private let storeQueue = DispatchQueue(label: "com.helios.webview.store")
	private let queueKey = DispatchSpecificKey<Bool>()
	
	private init() {
		storeQueue.setSpecific(key: queueKey, value: true)
	}
	
	private func synchronize<T>(_ block: () -> T) -> T {
		if DispatchQueue.getSpecific(key: queueKey) == true {
			return block()
		} else {
			return storeQueue.sync(execute: block)
		}
	}
	
	func getOrCreateWebView(for tabID: UUID, createWebView: () -> WKWebView) -> WKWebView {
		if let existingWebView = webViews[tabID] {
			return existingWebView
		} else {
			let newWebView = createWebView()
			webViews[tabID] = newWebView
			return newWebView
		}
	}
	
	func getCurrentWebView(for tabID: UUID) -> WKWebView? {
		return synchronize {
			return webViews[tabID]
		}
	}
	
	func remove(for tabID: UUID) {
		webViews.removeValue(forKey: tabID)
	}
	
	func removeAll() {
		synchronize {
			print("Removing all WebViews")
			webViews.forEach { (_, webView) in
				webView.stopLoading()
				webView.navigationDelegate = nil
				webView.uiDelegate = nil
				webView.removeFromSuperview()
			}
			webViews.removeAll()
			lastURLs.removeAll()
			loadingTabIDs.removeAll()
		}
	}
	
	func isTabLoading(_ tabID: UUID) -> Bool {
		return synchronize {
			loadingTabIDs.contains(tabID)
		}
	}
	
	func markTabLoading(_ tabID: UUID) {
		synchronize {
			loadingTabIDs.insert(tabID)
		}
	}
	
	func markTabFinishedLoading(_ tabID: UUID) {
		synchronize {
			loadingTabIDs.remove(tabID)
		}
	}
	
	func goBack(for tabID: UUID) {
		if let webView = getCurrentWebView(for: tabID) {
			webView.goBack()
		}
	}
	
	func goForward(for tabID: UUID) {
		if let webView = getCurrentWebView(for: tabID) {
			webView.goForward()
		}
	}
	
	func stopLoading(for tabID: UUID) {
		if let webView = getCurrentWebView(for: tabID) {
			webView.stopLoading()
			markTabFinishedLoading(tabID)
		}
	}
	
	func reload(for tabID: UUID) {
		if let webView = getCurrentWebView(for: tabID),
		   !isTabLoading(tabID) {
			markTabLoading(tabID)
			webView.reload()
		}
	}
	
	func clearWebView(for tabID: UUID) {
		synchronize {
			if let webView = webViews.removeValue(forKey: tabID) {
				webView.stopLoading()
				webView.navigationDelegate = nil
				webView.uiDelegate = nil
			}
			lastURLs.removeValue(forKey: tabID)
			loadingTabIDs.remove(tabID)
		}
	}
}
