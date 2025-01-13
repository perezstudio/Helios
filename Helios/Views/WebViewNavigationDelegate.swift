//
//  WebViewNavigationDelegate.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import SwiftUI
import SwiftData
import WebKit

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
	private weak var tab: Tab?
	private let onTitleUpdate: (String?) -> Void
	private let onUrlUpdate: (String) -> Void
	
	init(tab: Tab, onTitleUpdate: @escaping (String?) -> Void, onUrlUpdate: @escaping (String) -> Void) {
		self.tab = tab
		self.onTitleUpdate = onTitleUpdate
		self.onUrlUpdate = onUrlUpdate
		super.init()
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// Update title
		onTitleUpdate(webView.title)
		
		// Update URL to ensure we have the final URL after any redirects
		if let currentURL = webView.url?.absoluteString {
			tab?.url = currentURL
		}
		
		// Fetch favicon
		fetchFavicon(webView: webView)
	}
	
	private func fetchFavicon(webView: WKWebView) {
		guard let tab = tab,
			  let currentURL = webView.url,
			  let baseURL = currentURL.baseURL ?? URL(string: currentURL.absoluteString) else { return }
		
		// Try common favicon locations
		let faviconURLs = [
			baseURL.appendingPathComponent("favicon.ico"),
			baseURL.appendingPathComponent("favicon.png"),
			URL(string: "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")/favicon.ico")
		].compactMap { $0 }
		
		// Also check for favicon link in HTML
		webView.evaluateJavaScript("""
			var link = document.querySelector("link[rel~='icon']");
			link ? link.href : null;
		""") { (result, error) in
			if let faviconURLString = result as? String,
			   let faviconURL = URL(string: faviconURLString) {
				self.downloadFavicon(from: faviconURL)
			} else {
				// Try common locations if no favicon link found
				self.tryNextFaviconURL(urls: Array(faviconURLs), index: 0)
			}
		}
	}
	
	private func tryNextFaviconURL(urls: [URL], index: Int) {
		guard index < urls.count else { return }
		
		downloadFavicon(from: urls[index]) { success in
			if !success && index + 1 < urls.count {
				self.tryNextFaviconURL(urls: urls, index: index + 1)
			}
		}
	}
	
	private func downloadFavicon(from url: URL, completion: ((Bool) -> Void)? = nil) {
		let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self,
				  let data = data,
				  let response = response as? HTTPURLResponse,
				  response.statusCode == 200,
				  let tab = self.tab else {
				completion?(false)
				return
			}
			
			DispatchQueue.main.async {
				tab.faviconData = data
				completion?(true)
			}
		}
		task.resume()
	}
}
