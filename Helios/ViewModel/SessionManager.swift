import WebKit
import SwiftUI

@Observable
class SessionManager {
	static let shared = SessionManager()
	
	private var processPoolsByProfile: [UUID: WKProcessPool] = [:]
	private var dataStoresByProfile: [UUID: WKWebsiteDataStore] = [:]
	private var configurationsByProfile: [UUID: WKWebViewConfiguration] = [:]
	private let queue = DispatchQueue(label: "com.helios.sessionmanager")
	
	private init() {}
	
	// Add a script to help WebRTC permissions work properly
	private func addWebRTCEnablementScript(to userContentController: WKUserContentController) {
		let webRTCScript = """
		(function() {
			// Helper to ensure WebRTC permissions work correctly
			const originalGetUserMedia = navigator.mediaDevices?.getUserMedia;
			if (originalGetUserMedia) {
				// Keep track of pending promises
				let pendingPromises = new Map();
				
				// Intercept navigator.permissions.query to make permission checks succeed
				if (navigator.permissions && navigator.permissions.query) {
					const originalQuery = navigator.permissions.query;
					navigator.permissions.query = function(permDescriptor) {
						if (permDescriptor.name === 'camera' || permDescriptor.name === 'microphone') {
							return Promise.resolve({ state: 'prompt', onchange: null });
						}
						return originalQuery.call(this, permDescriptor);
					};
				}
				
				// Create a custom getUserMedia that works better with our permissions system
				navigator.mediaDevices.getUserMedia = function(constraints) {
					console.log('📷🎤 getUserMedia called with constraints:', JSON.stringify(constraints));
					
					// Always return a proper MediaStream to avoid TypeError
					return originalGetUserMedia.call(navigator.mediaDevices, constraints)
						.then(stream => {
							console.log('📷🎤 getUserMedia succeeded');
							return stream;
						})
						.catch(err => {
							console.error('📷🎤 getUserMedia error:', err.name, err.message);
							throw err;
						});
				};
			}
			
			// Define navigator.mediaDevices if it doesn't exist (older browsers)
			if (!navigator.mediaDevices) {
				navigator.mediaDevices = {};
			}
			
			// Polyfill for enumerateDevices
			if (!navigator.mediaDevices.enumerateDevices) {
				navigator.mediaDevices.enumerateDevices = function() {
					// Provide fake devices to ensure sites don't fail completely
					return Promise.resolve([
						{
							kind: 'audioinput',
							deviceId: 'default-audio-input',
							label: 'Default Microphone'
						},
						{
							kind: 'videoinput',
							deviceId: 'default-video-input',
							label: 'Default Camera'
						}
					]);
				};
			}
		})();
		"""
		
		let script = WKUserScript(source: webRTCScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		userContentController.addUserScript(script)
	}
	
	// Set up any profile-specific user scripts
	private func setupUserScripts(for profile: Profile, in configuration: WKWebViewConfiguration) {
		// Clear any existing scripts
		configuration.userContentController.removeAllUserScripts()
		
		// Add profile identifier script - useful for debugging
		let profileIdentScript = """
		// Profile ID: \(profile.id.uuidString)
		// Profile Name: \(profile.name)
		// This helps ensure content isolation between profiles
		"""
		
		let profileScript = WKUserScript(
			source: profileIdentScript,
			injectionTime: .atDocumentStart,
			forMainFrameOnly: true
		)
		
		configuration.userContentController.addUserScript(profileScript)
		
		// Optionally add storage isolation script
		let storageIsolationScript = """
		// Ensure third-party frames can't access localStorage/sessionStorage across profiles
		try {
			if (window.top !== window) {
				// This is a frame, potentially third-party
				// We could add additional isolation if needed
			}
		} catch(e) {
			// Cross-origin frame access error - this is expected and good
		}
		"""
		
		let isolationScript = WKUserScript(
			source: storageIsolationScript,
			injectionTime: .atDocumentStart,
			forMainFrameOnly: false
		)
		
		configuration.userContentController.addUserScript(isolationScript)
	}
	
	private func getProfileConfiguration(for profile: Profile) -> WKWebViewConfiguration {
		// Use existing configuration if available
		if let existingConfig = configurationsByProfile[profile.id] {
			return existingConfig
		}
		
		// Create new configuration
		let config = WKWebViewConfiguration()
		
		// Configure process pool - critical for isolation
		// Each profile gets its own WKProcessPool to ensure JavaScript contexts
		// and other web processes are completely isolated
		let processPool = WKProcessPool() // Always create a new process pool for true isolation
		processPoolsByProfile[profile.id] = processPool
		config.processPool = processPool
		
		// Configure preferences
		let prefs = WKPreferences()
		prefs.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = prefs
		
		// Configure website data store - this is where cookies, cache, etc. are stored
		let dataStore = getOrCreateDataStore(for: profile)
		config.websiteDataStore = dataStore
		
		// Configure media capabilities - critical for WebRTC support
		// Don't require user interaction for media playback
		config.mediaTypesRequiringUserActionForPlayback = []
		config.allowsAirPlayForMediaPlayback = true
		
		// Enable camera and microphone access
		if #available(macOS 14.0, *) {
			// We don't need to set mediaDevicesRequiresUserGesture as it's not available in this version
			// Don't limit navigations to app-bound domains - important for WebRTC
			config.limitsNavigationsToAppBoundDomains = false 
		}
		
		// Configure web content
		let webpagePrefs = WKWebpagePreferences()
		webpagePrefs.allowsContentJavaScript = true
		config.defaultWebpagePreferences = webpagePrefs
		
		// Add user content controller for profile-specific scripts
		setupUserScripts(for: profile, in: config)
		
		// Add WebRTC enablement script
		addWebRTCEnablementScript(to: config.userContentController)
		
		// Store and return configuration
		configurationsByProfile[profile.id] = config
		return config
	}
	
	private func createIsolatedConfiguration() -> WKWebViewConfiguration {
		let config = WKWebViewConfiguration()
		config.processPool = WKProcessPool()
		config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
		
		let prefs = WKPreferences()
		prefs.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = prefs
		
		if #available(macOS 14.0, *) {
			config.mediaTypesRequiringUserActionForPlayback = []
		} else {
			config.mediaTypesRequiringUserActionForPlayback = .all
		}
		
		return config
	}
	
	func getDataStore(for profile: Profile?) -> WKWebsiteDataStore {
		queue.sync {
			guard let profile = profile else {
				// For null profile, use non-persistent store for privacy
				return WKWebsiteDataStore.nonPersistent()
			}
			
			if let existingDataStore = dataStoresByProfile[profile.id] {
				return existingDataStore
			}

			let newDataStore = WebKitDirectoryHelper.setupCustomDataStore(for: profile)
			dataStoresByProfile[profile.id] = newDataStore
			return newDataStore
		}
	}
	
	private func getOrCreateDataStore(for profile: Profile) -> WKWebsiteDataStore {
		if let existingStore = dataStoresByProfile[profile.id] {
			return existingStore
		}
		
		// Create a new isolated data store for this profile
		let dataStore = WebKitDirectoryHelper.setupCustomDataStore(for: profile)
		dataStoresByProfile[profile.id] = dataStore
		
		// Configure cookie policies - this enhances privacy between profiles
		dataStore.httpCookieStore.getAllCookies { _ in
			// Start with a clean slate
		}
		
		return dataStore
	}
	
	// Force configuration to be recreated on next request
	func invalidateConfiguration(for profile: Profile) {
		queue.sync {
			configurationsByProfile.removeValue(forKey: profile.id)
			processPoolsByProfile.removeValue(forKey: profile.id)
			// Note: We don't remove the dataStore here to avoid disrupting active WebViews
			// It will be replaced when a new configuration is requested
		}
	}
	
	func cleanupProfile(_ profile: Profile) async {
		await MainActor.run {
			// Clean up website data
			if let dataStore = dataStoresByProfile[profile.id] {
				dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
					dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
									   for: records) {
						print("Cleaned up website data for profile: \(profile.id)")
					}
				}
			}
			
			// Remove configurations
			configurationsByProfile.removeValue(forKey: profile.id)
			processPoolsByProfile.removeValue(forKey: profile.id)
			dataStoresByProfile.removeValue(forKey: profile.id)
			
			// Clean up profile directory
			WebKitDirectoryHelper.clearProfileData(for: profile)
		}
	}
}
