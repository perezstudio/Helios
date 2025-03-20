//
//  WebView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import WebKit
import AVKit

struct WebView: NSViewRepresentable {
	@Binding var url: URL?
	var profile: Profile

	func makeNSView(context: Context) -> WKWebView {
		let configuration = WKWebViewConfiguration()
		configuration.websiteDataStore = SessionManager.shared.getDataStore(for: profile)

		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = context.coordinator
		webView.uiDelegate = context.coordinator
		
		// Add this to where you configure your WebView
		let permissionScript = """
		(function() {
			// Override getUserMedia to automatically resolve with mock streams
			const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
			navigator.mediaDevices.getUserMedia = function(constraints) {
				console.log('getUserMedia intercepted');
				// For debugging - check what permissions are being requested
				if (constraints.video) console.log('Video requested');
				if (constraints.audio) console.log('Audio requested');
				
				// Auto-grant without actually accessing hardware
				return originalGetUserMedia.call(this, constraints);
			};
			
			// Make permissions API always report granted
			if (navigator.permissions && navigator.permissions.query) {
				const originalQuery = navigator.permissions.query;
				navigator.permissions.query = function(permissionDesc) {
					if (permissionDesc.name === 'camera' || permissionDesc.name === 'microphone') {
						console.log(permissionDesc.name + ' permission auto-granted');
						return Promise.resolve({state: 'granted', onchange: null});
					}
					return originalQuery.call(this, permissionDesc);
				};
			}
		})();
		"""

		let script = WKUserScript(source: permissionScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		configuration.userContentController.addUserScript(script)

		return webView
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		if let url = url {
			let request = URLRequest(url: url)
			nsView.load(request)
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
		var parent: WebView

		init(_ parent: WebView) {
			self.parent = parent
			super.init()
		}

		// Setup Picture in Picture support
		func setupPictureInPicture(in webView: WKWebView) {
			let pipScript = """
			(function() {
				function enablePictureInPicture() {
					const videos = document.getElementsByTagName('video');
					for (const video of videos) {
						// More aggressive PiP configuration
						video.disablePictureInPicture = false;
						video.setAttribute('webkit-playsinline', '');
						video.setAttribute('playsinline', '');
						video.controls = true;
						
						// Specific YouTube handling
						if (window.location.hostname.includes('youtube.com')) {
							// Try to find YouTube's native video player
							const ytVideo = document.querySelector('video.html5-main-video');
							if (ytVideo) {
								ytVideo.disablePictureInPicture = false;
								ytVideo.setAttribute('webkit-playsinline', '');
								ytVideo.setAttribute('playsinline', '');
							}
						}
					}
				}

				// Run on initial page load
				enablePictureInPicture();

				// Setup MutationObserver to handle dynamically added videos
				const observer = new MutationObserver((mutations) => {
					enablePictureInPicture();
				});

				observer.observe(document.body, { 
					childList: true, 
					subtree: true 
				});

				// Add event listener to ensure PiP is always possible
				document.addEventListener('enterpictureinpicture', (event) => {
					console.log('Entered PiP');
				});

				document.addEventListener('leavepictureinpicture', (event) => {
					console.log('Left PiP');
				});
			})();
			"""
			
			webView.evaluateJavaScript(pipScript, completionHandler: nil)
		}

		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			setupPictureInPicture(in: webView)
		}

		// Method to manually toggle Picture in Picture
		func togglePictureInPicture(in webView: WKWebView) {
			let toggleScript = """
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
			})();
			"""
			
			webView.evaluateJavaScript(toggleScript, completionHandler: nil)
		}
	}
}
