import SwiftUI
import SwiftData
@preconcurrency import WebKit
import AVKit
import OSLog

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
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
			
			// Inject permission detection script
			injectPermissionDetectionScript(webView: webView, host: host)
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
		
		// Check for notification permission
		if let host = webView.url?.host, checkForNotificationPermissionRequest(navigationAction, host: host) {
			// Continue with navigation regardless of notification permission decision
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
	@MainActor
	func webView(_ webView: WKWebView, requestMediaCapturePermission: @escaping (WKPermissionDecision) -> Void) {
		print("Received media capture permission request")
		
		if let url = webView.url, let host = url.host, let tab = tab {
			// Check if we have stored settings for this domain
			if let settings = viewModel?.getPageSettings(for: tab) {
				// For camera and microphone we'll handle them together in this case
				if let cameraPermission = settings.camera, let micPermission = settings.microphone {
					// If both settings are the same (both allow or both block), use that decision
					if cameraPermission == micPermission {
						if cameraPermission == .allow {
							print("Auto-allowing media capture for \(host) based on saved settings")
							requestMediaCapturePermission(.grant)
						} else {
							print("Auto-denying media capture for \(host) based on saved settings")
							requestMediaCapturePermission(.deny)
						}
						return
					}
				}
			}
			
			// If we don't have settings or they're set to ask, request permission
			print("Requesting user decision for media capture on \(host)")
			
			// Request both camera and microphone permissions at once
			let cameraRequest = PermissionManager.PermissionRequest(
				domain: host,
				permission: .camera,
				defaultValue: .ask
			)
			
			PermissionManager.shared.requestPermission(for: host, permission: .camera)
			
			// Create observer for the permission response
			let notificationName = NSNotification.Name("PermissionResponseReceived")
			var observer: NSObjectProtocol?
			
			observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
				guard let userInfo = notification.userInfo,
					  let domain = userInfo["domain"] as? String,
					  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
					  let response = userInfo["response"] as? PermissionState,
					  domain == host, permissionFeature == .camera else {
					return
				}
				
				// Clean up observer
				if let observer = observer {
					NotificationCenter.default.removeObserver(observer)
				}
				
				// Also set microphone permission to match camera permission
				if let settings = self?.viewModel?.getPageSettings(for: tab) {
					settings.microphone = response
					try? self?.viewModel?.modelContext?.save()
				}
				
				// Grant or deny based on user decision
				if response == .allow {
					requestMediaCapturePermission(.grant)
				} else {
					requestMediaCapturePermission(.deny)
				}
			}
			
			// Store the observer
			if let observer = observer {
				viewModel?.permissionObservers["\(host)-camera"] = observer
			}
		} else {
			// Default deny if we can't determine the host
			requestMediaCapturePermission(.deny)
		}
	}

	// WKUIDelegate methods for permissions
	
	// Geolocation permission handler
	@MainActor
	func webView(_ webView: WKWebView, requestGeolocationPermissionFor frame: WKFrameInfo, initiatedByFrame: Bool, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
		print("Received geolocation permission request")
		
		if let url = webView.url, let host = url.host, let tab = tab {
			// Check if we have stored settings
			if let settings = viewModel?.getPageSettings(for: tab), let locationPermission = settings.location {
				if locationPermission == .allow {
					print("Auto-allowing location for \(host) based on saved settings")
					decisionHandler(.grant)
					return
				} else if locationPermission == .block {
					print("Auto-denying location for \(host) based on saved settings")
					decisionHandler(.deny)
					return
				}
			}
			
			// If set to ask, request permission
			print("Requesting user decision for location on \(host)")
			PermissionManager.shared.requestPermission(for: host, permission: .location)
			
			// Set up observer for response
			let notificationName = NSNotification.Name("PermissionResponseReceived")
			var observer: NSObjectProtocol?
			
			observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
				guard let userInfo = notification.userInfo,
					  let domain = userInfo["domain"] as? String,
					  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
					  let response = userInfo["response"] as? PermissionState,
					  domain == host, permissionFeature == .location else {
					return
				}
				
				// Clean up observer
				if let observer = observer {
					NotificationCenter.default.removeObserver(observer)
				}
				
				// Grant or deny based on user decision
				if response == .allow {
					decisionHandler(.grant)
				} else {
					decisionHandler(.deny)
				}
			}
			
			// Store the observer
			if let observer = observer {
				viewModel?.permissionObservers["\(host)-location"] = observer
			}
		} else {
			// Default deny if we can't determine the host
			decisionHandler(.deny)
		}
	}
	
	// Handle notification permission requests as part of navigation
	private func checkForNotificationPermissionRequest(_ navigationAction: WKNavigationAction, host: String) -> Bool {
		// Try to detect notification permission requests
		if let secPurpose = navigationAction.request.value(forHTTPHeaderField: "Sec-Purpose"),
		   secPurpose.contains("notifications") {
			// Handle notification permission
			handleNotificationPermission(host: host, decisionHandler: { _ in })
			return true
		}
		return false
	}
	
	// Handle notification permission requests
	@MainActor
	private func handleNotificationPermission(host: String, decisionHandler: @escaping (Bool) -> Void) {
		guard let tab = tab else {
			decisionHandler(false)
			return
		}
		
		// Check if we have stored settings
		if let settings = viewModel?.getPageSettings(for: tab), let notificationPermission = settings.notifications {
			if notificationPermission == .allow {
				print("Auto-allowing notifications for \(host) based on saved settings")
				decisionHandler(true)
				return
			} else if notificationPermission == .block {
				print("Auto-denying notifications for \(host) based on saved settings")
				decisionHandler(false)
				return
			}
		}
		
		// If set to ask, request permission
		print("Requesting user decision for notifications on \(host)")
		PermissionManager.shared.requestPermission(for: host, permission: .notifications)
		
		// Set up observer for response
		let notificationName = NSNotification.Name("PermissionResponseReceived")
		var observer: NSObjectProtocol?
		
		observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
			guard let userInfo = notification.userInfo,
				  let domain = userInfo["domain"] as? String,
				  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
				  let response = userInfo["response"] as? PermissionState,
				  domain == host, permissionFeature == .notifications else {
				return
			}
			
			// Clean up observer
			if let observer = observer {
				NotificationCenter.default.removeObserver(observer)
			}
			
			// Grant or deny based on user decision
			decisionHandler(response == .allow)
		}
		
		// Store the observer
		if let observer = observer {
			viewModel?.permissionObservers["\(host)-notifications"] = observer
		}
	}
	
	// Helper method for showing permission alerts (for legacy code)
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
	
	// MARK: - Permission Script Handling
	
	// WebRTC specific fix for Google Meet and similar sites
	private func injectWebRTCFixScript(webView: WKWebView?) {
		let rtcFixScript = """
		(function() {
			console.log('Injecting WebRTC fix for camera and microphone');
			
			// Make sure permissions API always returns correct state
			if (navigator.permissions && navigator.permissions.query) {
				const originalQuery = navigator.permissions.query;
				navigator.permissions.query = function(permissionDesc) {
					if (permissionDesc.name === 'camera' || permissionDesc.name === 'microphone') {
						console.log('Auto-granting ' + permissionDesc.name + ' permission');
						return Promise.resolve({state: 'granted', onchange: null});
					}
					return originalQuery.call(this, permissionDesc);
				};
			}
			
			// Fix getUserMedia
			if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
				const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
				
				navigator.mediaDevices.getUserMedia = function(constraints) {
					console.log('getUserMedia intercepted with:', JSON.stringify(constraints));
					
					// Simplify constraints to avoid issues
					let simpleConstraints = constraints;
					if (typeof constraints.video === 'object' && Object.keys(constraints.video).length > 0) {
						// Just use a basic boolean to request video without complex constraints
						simpleConstraints = {
							audio: !!constraints.audio,
							video: true
						};
					}
					
					return originalGetUserMedia.call(this, simpleConstraints).catch(err => {
						console.error('getUserMedia failed:', err);
						
						// If error, try with even simpler constraints
						if (err.name === 'NotAllowedError' || err.name === 'NotFoundError') {
							return originalGetUserMedia.call(this, {audio: !!constraints.audio, video: !!constraints.video});
						}
						throw err;
					});
				};
			}
			
			// Mock device enumeration to ensure devices are found
			if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
				const originalEnumerate = navigator.mediaDevices.enumerateDevices;
				
				navigator.mediaDevices.enumerateDevices = function() {
					return originalEnumerate.call(this).then(devices => {
						// If no devices with labels, provide fake ones
						if (devices.every(d => !d.label)) {
							console.log('Providing mock device list');
							return [
								{kind: 'videoinput', deviceId: 'mock-camera', label: 'Integrated Camera', groupId: 'mock-group'},
								{kind: 'audioinput', deviceId: 'mock-mic', label: 'Internal Microphone', groupId: 'mock-group'}
							];
						}
						return devices;
					});
				};
			}
		})();
		"""
		
		webView?.evaluateJavaScript(rtcFixScript, completionHandler: nil)
	}

	// WKScriptMessageHandler implementation
	@MainActor
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		guard let tab = tab,
			  let url = URL(string: tab.url),
			  let host = url.host,
			  message.name == "permissionHandler",
			  let body = message.body as? [String: Any],
			  let permissionType = body["type"] as? String else {
			print("Invalid permission message received")
			return
		}
		
		let logger = Logger(subsystem: "com.helios.app", category: "Permissions")
		logger.debug("Received permission request: \(permissionType) for host: \(host)")
		
		switch permissionType {
		case "media":
			// Handle camera/microphone request
			handleMediaPermissionFromScript(host: host, webView: message.webView)
		
	// Also inject a WebRTC fix script
	injectWebRTCFixScript(webView: message.webView)
			
		case "geolocation":
			// Handle location request
			handleGeolocationPermissionFromScript(host: host, webView: message.webView)
			
		case "notifications":
			// Handle notifications request
			handleNotificationPermissionFromScript(host: host, webView: message.webView)
			
		default:
			logger.error("Unknown permission type: \(permissionType)")
		}
	}
	
	// Handle media permission requests from script
	@MainActor
	private func handleMediaPermissionFromScript(host: String, webView: WKWebView?) {
		guard let tab = tab else { return }
		
		if let settings = viewModel?.getPageSettings(for: tab), 
		   let cameraPermission = settings.camera {
			// Check if we already have a permission decision
			if cameraPermission != .ask {
				let isAllowed = cameraPermission == .allow
				// Send result back to the page
				let script = "window.heliosResolveMedia && window.heliosResolveMedia(\(isAllowed ? "true" : "false"));"
				webView?.evaluateJavaScript(script, completionHandler: nil)
				return
			}
		}
		
		// Request permission
		PermissionManager.shared.requestPermission(for: host, permission: .camera)
		
		// Set up observer for the response
		let notificationName = NSNotification.Name("PermissionResponseReceived")
		var observer: NSObjectProtocol?
		
		observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
			guard let userInfo = notification.userInfo,
				  let domain = userInfo["domain"] as? String,
				  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
				  let response = userInfo["response"] as? PermissionState,
				  domain == host, permissionFeature == .camera else {
				return
			}
			
			// Clean up observer
			if let observer = observer {
				NotificationCenter.default.removeObserver(observer)
			}
			
			// Also set microphone permission to match camera permission
			if let settings = self?.viewModel?.getPageSettings(for: tab) {
				settings.microphone = response
				try? self?.viewModel?.modelContext?.save()
			}
			
			// Send result back to the page
			let isAllowed = response == .allow
			let script = "window.heliosResolveMedia && window.heliosResolveMedia(\(isAllowed ? "true" : "false"));"
			webView?.evaluateJavaScript(script, completionHandler: nil)
		}
		
		// Store the observer
		if let observer = observer {
			viewModel?.permissionObservers["\(host)-camera-script"] = observer
		}
	}
	
	// Handle geolocation permission requests from script
	@MainActor
	private func handleGeolocationPermissionFromScript(host: String, webView: WKWebView?) {
		guard let tab = tab else { return }
		
		if let settings = viewModel?.getPageSettings(for: tab), 
		   let locationPermission = settings.location {
			// Check if we already have a permission decision
			if locationPermission != .ask {
				let isAllowed = locationPermission == .allow
				// Send result back to the page
				let script = "window.heliosResolveGeo && window.heliosResolveGeo(\(isAllowed ? "true" : "false"));"
				webView?.evaluateJavaScript(script, completionHandler: nil)
				return
			}
		}
		
		// Request permission
		PermissionManager.shared.requestPermission(for: host, permission: .location)
		
		// Set up observer for the response
		let notificationName = NSNotification.Name("PermissionResponseReceived")
		var observer: NSObjectProtocol?
		
		observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
			guard let userInfo = notification.userInfo,
				  let domain = userInfo["domain"] as? String,
				  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
				  let response = userInfo["response"] as? PermissionState,
				  domain == host, permissionFeature == .location else {
				return
			}
			
			// Clean up observer
			if let observer = observer {
				NotificationCenter.default.removeObserver(observer)
			}
			
			// Send result back to the page
			let isAllowed = response == .allow
			let script = "window.heliosResolveGeo && window.heliosResolveGeo(\(isAllowed ? "true" : "false"));"
			webView?.evaluateJavaScript(script, completionHandler: nil)
		}
		
		// Store the observer
		if let observer = observer {
			viewModel?.permissionObservers["\(host)-location-script"] = observer
		}
	}
	
	// Handle notification permission requests from script
	@MainActor
	private func handleNotificationPermissionFromScript(host: String, webView: WKWebView?) {
		guard let tab = tab else { return }
		
		if let settings = viewModel?.getPageSettings(for: tab), 
		   let notificationPermission = settings.notifications {
			// Check if we already have a permission decision
			if notificationPermission != .ask {
				let isAllowed = notificationPermission == .allow
				// Send result back to the page
				let script = "window.heliosResolveNotification && window.heliosResolveNotification(\(isAllowed ? "true" : "false"));"
				webView?.evaluateJavaScript(script, completionHandler: nil)
				return
			}
		}
		
		// Request permission
		PermissionManager.shared.requestPermission(for: host, permission: .notifications)
		
		// Set up observer for the response
		let notificationName = NSNotification.Name("PermissionResponseReceived")
		var observer: NSObjectProtocol?
		
		observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
			guard let userInfo = notification.userInfo,
				  let domain = userInfo["domain"] as? String,
				  let permissionFeature = userInfo["permission"] as? PermissionManager.PermissionFeature,
				  let response = userInfo["response"] as? PermissionState,
				  domain == host, permissionFeature == .notifications else {
				return
			}
			
			// Clean up observer
			if let observer = observer {
				NotificationCenter.default.removeObserver(observer)
			}
			
			// Send result back to the page
			let isAllowed = response == .allow
			let script = "window.heliosResolveNotification && window.heliosResolveNotification(\(isAllowed ? "true" : "false"));"
			webView?.evaluateJavaScript(script, completionHandler: nil)
		}
		
		// Store the observer
		if let observer = observer {
			viewModel?.permissionObservers["\(host)-notifications-script"] = observer
		}
	}
	
	// Inject script to detect permission requests
	private func injectPermissionDetectionScript(webView: WKWebView, host: String) {
		// Use MainActor to ensure thread safety
		Task { @MainActor in
			// Create a message handler for permissions
			let contentController = webView.configuration.userContentController
			
			// First try to remove any existing handler to prevent duplicates
			// This is safer and handles cases where the handler was already added
			try? contentController.removeScriptMessageHandler(forName: "permissionHandler")
			
			// Add our handler
			contentController.add(self, name: "permissionHandler")
			
			// JavaScript to intercept permission requests
			let permissionScript = """
			(function() {
				// Save a reference to the original methods
				const originalGetUserMedia = navigator.mediaDevices && navigator.mediaDevices.getUserMedia ? 
					navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices) : null;
					
				const originalGeolocation = navigator.geolocation ? 
					navigator.geolocation.getCurrentPosition.bind(navigator.geolocation) : null;
					
				const originalNotification = window.Notification ? 
					window.Notification.requestPermission.bind(window.Notification) : null;
					
				// Override getUserMedia for camera/microphone permissions
				if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
					navigator.mediaDevices.getUserMedia = function(constraints) {
						// Notify our custom handler
						window.webkit.messageHandlers.permissionHandler.postMessage({
							type: 'media',
							constraints: constraints
						});
						
						// Return a promise that will be resolved by our permission handler
						return new Promise((resolve, reject) => {
							window.heliosResolveMedia = function(allowed) {
								if (allowed) {
									// If allowed, call the original method
									originalGetUserMedia(constraints).then(resolve).catch(reject);
								} else {
									reject(new DOMException('Permission denied', 'NotAllowedError'));
								}
							};
						});
					};
				}
				
				// Override geolocation API
				if (navigator.geolocation) {
					navigator.geolocation.getCurrentPosition = function(success, error, options) {
						// Notify our custom handler
						window.webkit.messageHandlers.permissionHandler.postMessage({
							type: 'geolocation'
						});
						
						// Store callbacks for later use
						window.heliosGeoSuccess = success;
						window.heliosGeoError = error;
						window.heliosGeoOptions = options;
						
						// Response will be handled by permissionHandler
						window.heliosResolveGeo = function(allowed) {
							if (allowed) {
								originalGeolocation(success, error, options);
							} else {
								error && error({ code: 1, message: 'Permission denied' });
							}
						};
					};
				}
				
				// Override notifications API
				if (window.Notification) {
					window.Notification.requestPermission = function() {
						// Notify our custom handler
						window.webkit.messageHandlers.permissionHandler.postMessage({
							type: 'notifications'
						});
						
						// Return a promise that will be resolved by our permission handler
						return new Promise((resolve) => {
							window.heliosResolveNotification = function(allowed) {
								resolve(allowed ? 'granted' : 'denied');
							};
						});
					};
				}
			})();
			"""
			
			let userScript = WKUserScript(source: permissionScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
			contentController.addUserScript(userScript)
			
			// Also execute the script for the current page
			webView.evaluateJavaScript(permissionScript, completionHandler: nil)
		}
	}
	
	// MARK: - Cleanup

	deinit {
		// We need to be careful about thread safety here
		// Avoid direct access to viewModel properties during deallocation
		let webViewIdCopy = tab?.webViewId
		
		// Just post a notification to clean up the handler later on the main thread
		if let webViewId = webViewIdCopy {
			Task { @MainActor in
				// Use a notification to handle cleanup on the main thread
				NotificationCenter.default.post(
					name: NSNotification.Name("CleanupWebViewScriptHandler"),
					object: nil,
					userInfo: ["webViewId": webViewId, "handlerName": "permissionHandler"]
				)
			}
		}
		
		// Also remove any notification observers
		if let tabId = tab?.id {
			if let observers = viewModel?.permissionObservers {
				for key in observers.keys {
					if key.contains(tabId.uuidString) {
						if let observer = observers[key] {
							NotificationCenter.default.removeObserver(observer)
						}
					}
				}
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
