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
			onUrlUpdate(currentURL)
		}

		// Fetch favicon with retry mechanism
		fetchFavicon(webView: webView)
	}

	private func fetchFavicon(webView: WKWebView) {
		guard let tab = tab,
			  let currentURL = webView.url,
			  let baseURL = currentURL.baseURL ?? URL(string: currentURL.absoluteString) else { return }

		// Expanded list of potential favicon locations
		let faviconURLs = [
			baseURL.appendingPathComponent("favicon.ico"),
			baseURL.appendingPathComponent("favicon.png"),
			baseURL.appendingPathComponent("apple-touch-icon.png"),
			baseURL.appendingPathComponent("apple-touch-icon-precomposed.png"),
			URL(string: "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")/favicon.ico"),
			URL(string: "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")/apple-touch-icon.png")
		].compactMap { $0 }

		// First try to find favicon link in HTML
		let script = """
			(function() {
				var links = Array.from(document.getElementsByTagName('link'));
				var icon = links.find(link => 
					link.rel.includes('icon') || 
					link.rel.includes('shortcut icon') || 
					link.rel.includes('apple-touch-icon')
				);
				return icon ? icon.href : null;
			})()
		"""

		webView.evaluateJavaScript(script) { [weak self] (result, error) in
			guard let self = self else { return }
			
			if let faviconURLString = result as? String,
			   let faviconURL = URL(string: faviconURLString) {
				// Found favicon in HTML, try to download it
				self.downloadFavicon(from: faviconURL) { success in
					if !success {
						// If HTML favicon fails, try common locations
						self.tryNextFaviconURL(urls: Array(faviconURLs), index: 0)
					}
				}
			} else {
				// No favicon in HTML, try common locations
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

			// Verify the data is an image
			if let image = NSImage(data: data) {
				DispatchQueue.main.async {
					tab.faviconData = data
					completion?(true)
				}
			} else {
				completion?(false)
			}
		}
		task.resume()
	}
}
