import SwiftUI
import SwiftData
@preconcurrency import WebKit
import AVKit

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
	private weak var tab: Tab?
	private let onTitleUpdate: (String?) -> Void
	private let onUrlUpdate: (String) -> Void
	private weak var viewModel: BrowserViewModel?
	private let windowId: UUID
	
	init(tab: Tab,
		 windowId: UUID,
		 viewModel: BrowserViewModel,
		 onTitleUpdate: @escaping (String?) -> Void,
		 onUrlUpdate: @escaping (String) -> Void) {
		self.tab = tab
		self.windowId = windowId
		self.viewModel = viewModel
		self.onTitleUpdate = onTitleUpdate
		self.onUrlUpdate = onUrlUpdate
		super.init()
	}

	// MARK: - WKNavigationDelegate
	
	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if let tab = tab {
			viewModel?.setTabLoading(tab, isLoading: true)
		}
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if let tab = tab {
			viewModel?.setTabLoading(tab, isLoading: false)
		}
		
		onTitleUpdate(webView.title)
		if let currentURL = webView.url?.absoluteString {
			tab?.url = currentURL
			onUrlUpdate(currentURL)
		}
		fetchFavicon(webView: webView)
		
		// Check permissions for the current site
		if let host = webView.url?.host {
			checkAndRequestPermissions(for: host, webView: webView)
		}
		
		// Enhanced PiP setup script
		let script = """
			const videos = document.getElementsByTagName('video');
			for (const video of videos) {
				if (!video.hasAttribute('webkit-playsinline')) {
					video.setAttribute('webkit-playsinline', '');
					video.setAttribute('playsinline', '');
					video.setAttribute('x-webkit-airplay', 'allow');
				}
				
				// Ensure controls are visible and PiP is enabled
				video.controls = true;
				video.disablePictureInPicture = false;
			}
			
			// Observe for new video elements
			const observer = new MutationObserver((mutations) => {
				mutations.forEach((mutation) => {
					mutation.addedNodes.forEach((node) => {
						if (node.nodeName === 'VIDEO') {
							node.setAttribute('webkit-playsinline', '');
							node.setAttribute('playsinline', '');
							node.setAttribute('x-webkit-airplay', 'allow');
							node.controls = true;
							node.disablePictureInPicture = false;
						}
					});
				});
			});
			
			observer.observe(document.body, {
				childList: true,
				subtree: true
			});
		"""
		
		webView.evaluateJavaScript(script, completionHandler: nil)
	}

	func webView(_ webView: WKWebView, didStartMediaPlaybackFor source: WKFrameInfo) {
		// Enhanced script for media playback
		let script = """
			const video = document.querySelector('video');
			if (video) {
				video.controls = true;
				video.disablePictureInPicture = false;
			}
		"""
		webView.evaluateJavaScript(script, completionHandler: nil)
	}

	// Toggle Picture in Picture
	func togglePictureInPicture(in webView: WKWebView) {
		let script = """
		(function() {
			const videos = document.getElementsByTagName('video');
			if (videos.length > 0) {
				const video = videos[0];
				if (document.pictureInPictureElement) {
					document.exitPictureInPicture();
				} else if (document.pictureInPictureEnabled) {
					video.requestPictureInPicture();
				}
			}
		})()
		"""
		webView.evaluateJavaScript(script, completionHandler: nil)
	}

	// Handle JavaScript preferences
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
		// Configure JavaScript permission
		if let tab = tab,
		   let settings = viewModel?.getPageSettings(for: tab),
		   let jsPermission = settings.javascript {
			preferences.allowsContentJavaScript = (jsPermission == .allow)
		} else {
			// Default to allowing JavaScript if no explicit setting
			preferences.allowsContentJavaScript = true
		}
		
		// Handle URL policies
		guard let url = navigationAction.request.url else {
			decisionHandler(.allow, preferences)
			return
		}
		
		// Skip handling for same-page anchors and javascript: URLs
		if url.absoluteString.hasPrefix("javascript:") ||
		   (url.fragment != nil && url.absoluteString.hasPrefix(webView.url?.absoluteString ?? "")) {
			decisionHandler(.allow, preferences)
			return
		}
		
		// Special URL schemes handling
		if let scheme = url.scheme?.lowercased(),
		   ["mailto", "tel", "facetime", "maps", "itms-apps"].contains(scheme) {
			NSWorkspace.shared.open(url)
			decisionHandler(.cancel, preferences)
			return
		}
		
		// Handle navigation types
		switch navigationAction.navigationType {
		case .linkActivated:
			let shouldOpenInNewTab = shouldOpenInNewTab(navigationAction)
			
			if shouldOpenInNewTab {
				Task { @MainActor in
					await viewModel?.addNewTab(
						windowId: windowId,
						title: "New Tab",
						url: url.absoluteString
					)
				}
				decisionHandler(.cancel, preferences)
			} else {
				decisionHandler(.allow, preferences)
			}
			
		case .formSubmitted, .formResubmitted, .backForward, .reload:
			decisionHandler(.allow, preferences)
			
		case .other:
			if navigationAction.targetFrame == nil {
				// New window request
				Task { @MainActor in
					await viewModel?.addNewTab(
						windowId: windowId,
						title: "New Tab",
						url: url.absoluteString
					)
				}
				decisionHandler(.cancel, preferences)
			} else {
				decisionHandler(.allow, preferences)
			}
			
		@unknown default:
			decisionHandler(.allow, preferences)
		}
	}
	
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		if let tab = tab {
			viewModel?.setTabLoading(tab, isLoading: false)
		}
	}
	
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		if let tab = tab {
			viewModel?.setTabLoading(tab, isLoading: false)
		}
	}
	
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard let url = navigationAction.request.url else {
			decisionHandler(.allow)
			return
		}
		
		// Skip handling for same-page anchors and javascript: URLs
		if url.absoluteString.hasPrefix("javascript:") ||
		   (url.fragment != nil && url.absoluteString.hasPrefix(webView.url?.absoluteString ?? "")) {
			decisionHandler(.allow)
			return
		}
		
		// Special URL schemes handling
		if let scheme = url.scheme?.lowercased(),
		   ["mailto", "tel", "facetime", "maps", "itms-apps"].contains(scheme) {
			NSWorkspace.shared.open(url)
			decisionHandler(.cancel)
			return
		}
		
		// Handle link clicks based on type and modifiers
		switch navigationAction.navigationType {
		case .linkActivated:
			let shouldOpenInNewTab = shouldOpenInNewTab(navigationAction)
			
			if shouldOpenInNewTab {
				Task { @MainActor in
					await viewModel?.addNewTab(
						windowId: windowId,
						title: "New Tab",
						url: url.absoluteString
					)
				}
				decisionHandler(.cancel)
			} else {
				decisionHandler(.allow)
			}
			
		case .formSubmitted, .formResubmitted:
			// Always handle forms in the current tab
			decisionHandler(.allow)
			
		case .backForward, .reload:
			// Navigation controls - allow in current tab
			decisionHandler(.allow)
			
		case .other:
			// For other actions, handle pop-up windows
			if navigationAction.targetFrame == nil {
				// This is likely a new window request (e.g., window.open())
				Task { @MainActor in
					await viewModel?.addNewTab(
						windowId: windowId,
						title: "New Tab",
						url: url.absoluteString
					)
				}
				decisionHandler(.cancel)
			} else {
				decisionHandler(.allow)
			}
			
		@unknown default:
			decisionHandler(.allow)
		}
	}
	
	private func shouldOpenInNewTab(_ navigationAction: WKNavigationAction) -> Bool {
		// Command click (macOS standard for new tab)
		if navigationAction.modifierFlags.contains(.command) {
			return true
		}
		
		// Middle-click (if detected)
		if navigationAction.buttonNumber == 1 {
			return true
		}
		
		// Check for target="_blank" or rel="noopener" links
		if navigationAction.targetFrame == nil {
			return true
		}
		
		// Handle window.open() JavaScript calls
		if !navigationAction.targetFrame!.isMainFrame {
			return true
		}
		
		return false
	}

	// MARK: - WKUIDelegate
	
	func webView(_ webView: WKWebView,
				 createWebViewWith configuration: WKWebViewConfiguration,
				 for navigationAction: WKNavigationAction,
				 windowFeatures: WKWindowFeatures) -> WKWebView? {
		
		// Always open these in a new tab
		if let url = navigationAction.request.url {
			Task { @MainActor in
				await viewModel?.addNewTab(
					windowId: windowId,
					title: "New Tab",
					url: url.absoluteString,
					configuration: configuration
				)
			}
		}
		
		// Return nil to indicate we've handled it in our own way
		return nil
	}
	
	// MARK: - Permission Helpers
	
	private func checkAndRequestPermissions(for host: String, webView: WKWebView) {
		guard let tab = tab,
			  let settings = viewModel?.getPageSettings(for: tab) else { return }
		
		// Initialize default permissions if needed
		if settings.camera == nil { settings.camera = .ask }
		if settings.microphone == nil { settings.microphone = .ask }
		if settings.location == nil { settings.location = .ask }
		if settings.notifications == nil { settings.notifications = .ask }
		if settings.javascript == nil { settings.javascript = .allow }
		
		try? viewModel?.modelContext?.save()
		
		// Apply JavaScript setting immediately
		if let jsPermission = settings.javascript {
			webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = (jsPermission == .allow)
		}
	}
	
	private func handlePermissionPrompt(host: String, message: String, permission: PermissionManager.PermissionFeature, completion: @escaping (Bool) -> Void) {
		// If the permission manager is already showing a request, use it
		if let activeRequest = PermissionManager.shared.activeRequest,
		   activeRequest.domain == host && activeRequest.permission == permission {
			// Create observer variable before using it in closure
			let notificationName = NSNotification.Name("PermissionResponseReceived")
			var observer: NSObjectProtocol?
			
			// Now initialize the observer with the variable already declared
			observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { notification in
				guard let userInfo = notification.userInfo,
					  let domain = userInfo["domain"] as? String,
					  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
					  let response = userInfo["response"] as? PermissionState,
					  domain == host && permissionFeature == permission else {
					return
				}
				
				if let observer = observer {
					NotificationCenter.default.removeObserver(observer)
				}
				completion(response == .allow)
			}
			
			// Store the observer to clean up later
			if let observer = observer {
				viewModel?.permissionObservers["\(host)-\(permission.rawValue)"] = observer
			}
			return
		}
		
		// Otherwise, create our own request
		PermissionManager.shared.requestPermission(for: host, permission: permission)
		
		// Create observer variable before using it in closure
		let notificationName = NSNotification.Name("PermissionResponseReceived")
		var observer: NSObjectProtocol?
		
		// Now initialize the observer with the variable already declared
		observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { notification in
			guard let userInfo = notification.userInfo,
				  let domain = userInfo["domain"] as? String,
				  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
				  let response = userInfo["response"] as? PermissionState,
				  domain == host && permissionFeature == permission else {
				return
			}
			
			if let observer = observer {
				NotificationCenter.default.removeObserver(observer)
			}
			completion(response == .allow)
		}
		
		// Store the observer to clean up later
		if let observer = observer {
			viewModel?.permissionObservers["\(host)-\(permission.rawValue)"] = observer
		}
	}
	
	private func showPermissionRequest(host: String, message: String, completion: @escaping (Bool) -> Void) {
		let alert = NSAlert()
		alert.messageText = "Permission Request"
		alert.informativeText = message
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Allow")
		alert.addButton(withTitle: "Block")
		
		guard let window = NSApplication.shared.mainWindow else {
			completion(false)
			return
		}
		
		alert.beginSheetModal(for: window) { response in
			completion(response == .alertFirstButtonReturn)
		}
	}
	
	// Basic permission handlers - keep only what works
	func webView(_ webView: WKWebView, requestMediaCapturePermission: @escaping (WKPermissionDecision) -> Void) {
		print("Received media permission request")
		
		// Auto-approve for testing
		requestMediaCapturePermission(.grant)
		
		/* When you want to implement proper permissions later:
		if let url = webView.url, let host = url.host {
			showSimplePermissionAlert(
				title: "Camera and Microphone Access",
				message: "\(host) wants to use your camera and microphone.",
				callback: requestMediaCapturePermission
			)
		} else {
			requestMediaCapturePermission(.deny)
		}
		*/
	}

	// Helper method for showing permission alerts (for later use)
	private func showSimplePermissionAlert(title: String, message: String, callback: @escaping (WKPermissionDecision) -> Void) {
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.messageText = title
			alert.informativeText = message
			alert.alertStyle = .informational
			alert.addButton(withTitle: "Allow")
			alert.addButton(withTitle: "Block")
			
			if let window = NSApplication.shared.keyWindow {
				alert.beginSheetModal(for: window) { response in
					let allowed = response == .alertFirstButtonReturn
					callback(allowed ? .grant : .deny)
				}
			} else {
				callback(.deny)
			}
		}
	}
	
	// MARK: - Favicon Handling
	
	private func fetchFavicon(webView: WKWebView) {
		guard let tab = tab,
			  let currentURL = webView.url,
			  let baseURL = currentURL.baseURL ?? URL(string: currentURL.absoluteString) else { return }

		let faviconURLs = [
			baseURL.appendingPathComponent("favicon.ico"),
			baseURL.appendingPathComponent("favicon.png"),
			baseURL.appendingPathComponent("apple-touch-icon.png"),
			baseURL.appendingPathComponent("apple-touch-icon-precomposed.png"),
			URL(string: "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")/favicon.ico"),
			URL(string: "\(baseURL.scheme ?? "https")://\(baseURL.host ?? "")/apple-touch-icon.png")
		].compactMap { $0 }

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
				self.downloadFavicon(from: faviconURL) { success in
					if !success {
						self.tryNextFaviconURL(urls: Array(faviconURLs), index: 0)
					}
				}
			} else {
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
