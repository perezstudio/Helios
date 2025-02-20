//
//  WebViewContainer.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import SwiftUI
import WebKit
import AVKit

struct WebViewContainer: NSViewRepresentable {
	let webView: WKWebView
	
	func makeNSView(context: Context) -> WKWebView {
		webView.frame = .zero
		webView.allowsMagnification = true
		
		// Set up PiP support
		if let videoElement = webView.configuration.userContentController.userScripts.first(where: { $0.source.contains("video") }) {
			setupPictureInPicture(for: webView)
		}
		
		return webView
	}
	
	func updateNSView(_ nsView: WKWebView, context: Context) {
		// No need for updates as we're recreating the view when tab changes
	}
	
	private func setupPictureInPicture(for webView: WKWebView) {
		// Create the AVPlayerLayer and PiP controller
		if AVPictureInPictureController.isPictureInPictureSupported() {
			// Inject JavaScript to handle video elements
			let script = """
				function setupPiP() {
					const videos = document.getElementsByTagName('video');
					for (const video of videos) {
						if (!video.webkitSupportsPresentationMode) {
							video.webkitSetPresentationMode('inline');
						}
						
						// Add PiP button if not already present
						if (!video.hasAttribute('x-webkit-airplay')) {
							video.setAttribute('x-webkit-airplay', 'allow');
							video.setAttribute('webkit-playsinline', '');
							video.setAttribute('playsinline', '');
						}
					}
				}
				
				// Run on page load
				setupPiP();
				
				// Watch for new video elements
				const observer = new MutationObserver((mutations) => {
					mutations.forEach((mutation) => {
						if (mutation.addedNodes) {
							mutation.addedNodes.forEach((node) => {
								if (node.nodeName === 'VIDEO') {
									setupPiP();
								}
							});
						}
					});
				});
				
				observer.observe(document.body, {
					childList: true,
					subtree: true
				});
			"""
			
			let userScript = WKUserScript(
				source: script,
				injectionTime: .atDocumentEnd,
				forMainFrameOnly: false
			)
			
			webView.configuration.userContentController.addUserScript(userScript)
		}
	}
}

class PiPCoordinator: NSObject, AVPictureInPictureControllerDelegate {
	private var pipController: AVPictureInPictureController?
	private weak var webView: WKWebView?
	
	init(webView: WKWebView) {
		super.init()
		self.webView = webView
		
		// Setup PiP controller when video is playing
		let script = """
			document.querySelector('video')?.webkitSetPresentationMode('picture-in-picture');
		"""
		
		webView.evaluateJavaScript(script) { [weak self] _, error in
			if let error = error {
				print("Error setting up PiP: \(error)")
			}
		}
	}
	
	// MARK: - AVPictureInPictureControllerDelegate
	
	func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		print("PiP will start")
	}
	
	func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		print("PiP did start")
	}
	
	func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
		print("PiP failed to start: \(error)")
	}
	
	func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		print("PiP will stop")
	}
	
	func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		print("PiP did stop")
	}
}
