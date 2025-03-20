import Foundation
import WebKit

// Extension for Browser WebRTC configuration
extension BrowserViewModel {
    
    // Configuration method to replace the SessionManager.getConfiguration method 
    func getProfileConfiguration(for profile: Profile?) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // Configure with profile preferences
        config.processPool = WKProcessPool() // Use a fresh process pool
        config.websiteDataStore = SessionManager.shared.getDataStore(for: profile)
        
        // Configure preferences
        let prefs = WKPreferences()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = prefs
        
        // Allow media playback without user interaction
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        
        // Disable app-bound domain limitations for WebRTC
        if #available(macOS 14.0, *) {
            config.limitsNavigationsToAppBoundDomains = false
        }
        
        // Configure JavaScript preferences
        if let webpagePrefs = config.defaultWebpagePreferences {
            webpagePrefs.allowsContentJavaScript = true
        }
        
        // Add WebRTC helper script
        let webRTCScript = """
        (function() {
            // Enhanced WebRTC permissions and compatibility script
            console.log('⚡️ Initializing WebRTC helper script');
            
            // Ensure navigator.mediaDevices exists
            if (!navigator.mediaDevices) {
                navigator.mediaDevices = {};
                console.log('📱 Created mediaDevices object');
            }
            
            // Ensure getUserMedia exists
            if (!navigator.mediaDevices.getUserMedia) {
                navigator.mediaDevices.getUserMedia = function(constraints) {
                    return Promise.reject(new DOMException('getUserMedia is not implemented in this browser', 'NotSupportedError'));
                };
                console.log('📱 Added getUserMedia placeholder');
            }
            
            // Store the original getUserMedia
            const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
            
            // Override permissions API to always succeed for WebRTC
            if (navigator.permissions && navigator.permissions.query) {
                const originalQuery = navigator.permissions.query;
                navigator.permissions.query = function(permDescriptor) {
                    console.log('🔐 Permission query for:', permDescriptor.name);
                    if (permDescriptor.name === 'camera' || permDescriptor.name === 'microphone') {
                        // Return granted state to allow WebRTC to work
                        return Promise.resolve({ state: 'granted', onchange: null });
                    }
                    return originalQuery.call(this, permDescriptor);
                };
                console.log('🔐 Enhanced permissions API');
            }
            
            // Create enhanced getUserMedia implementation
            navigator.mediaDevices.getUserMedia = function(constraints) {
                console.log('📷🎤 getUserMedia called with:', JSON.stringify(constraints));
                
                // Apply any needed constraint modifications
                let modifiedConstraints = JSON.parse(JSON.stringify(constraints)); // Deep copy
                
                // Special handling for video constraints
                if (constraints.video) {
                    // Ensure we're using reasonable defaults for video
                    if (typeof constraints.video === 'object') {
                        if (!constraints.video.width && !constraints.video.height) {
                            modifiedConstraints.video.width = { ideal: 1280 };
                            modifiedConstraints.video.height = { ideal: 720 };
                        }
                    }
                }
                
                // Forward the call to the original implementation
                return originalGetUserMedia.call(navigator.mediaDevices, modifiedConstraints)
                    .then(function(stream) {
                        console.log('📷🎤 getUserMedia succeeded');
                        return stream;
                    })
                    .catch(function(error) {
                        console.error('📷🎤 getUserMedia error:', error.name, error.message);
                        
                        // Create mock streams as a fallback if permission denied
                        if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                            console.log('📷🎤 Permission denied, attempting fallback');
                            
                            // Try again with prompt UI if possible
                            return originalGetUserMedia.call(navigator.mediaDevices, modifiedConstraints);
                        }
                        
                        // Re-throw the original error if we couldn't handle it
                        throw error;
                    });
            };
            
            // Enhanced enumerateDevices to always return some devices
            const originalEnumerateDevices = navigator.mediaDevices.enumerateDevices;
            navigator.mediaDevices.enumerateDevices = function() {
                if (originalEnumerateDevices) {
                    return originalEnumerateDevices.call(navigator.mediaDevices)
                        .then(function(devices) {
                            // If no devices found, return mock devices
                            if (!devices || devices.length === 0) {
                                return [
                                    {
                                        kind: 'audioinput',
                                        deviceId: 'default-audio-input',
                                        groupId: 'default-group',
                                        label: 'Default Microphone'
                                    },
                                    {
                                        kind: 'videoinput',
                                        deviceId: 'default-video-input',
                                        groupId: 'default-group',
                                        label: 'Default Camera'
                                    }
                                ];
                            }
                            return devices;
                        });
                } else {
                    // Fallback for browsers without native support
                    return Promise.resolve([
                        {
                            kind: 'audioinput',
                            deviceId: 'default-audio-input',
                            groupId: 'default-group',
                            label: 'Default Microphone'
                        },
                        {
                            kind: 'videoinput',
                            deviceId: 'default-video-input',
                            groupId: 'default-group',
                            label: 'Default Camera'
                        }
                    ]);
                }
            };
            
            console.log('✅ WebRTC helper script initialization complete');
        })();
        """
        
        let script = WKUserScript(source: webRTCScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        
        return config
    }
    
    // Helper for enabling WebRTC on an existing WebView
    func enableWebRTCForWebView(_ webView: WKWebView) {
        // Add the WebRTC helper script
        let webRTCScript = """
        (function() {
            // Enhanced WebRTC permissions and compatibility script
            console.log('⚡️ Initializing WebRTC helper script');
            
            // Make permissions API always report granted for camera/microphone
            if (navigator.permissions && navigator.permissions.query) {
                const originalQuery = navigator.permissions.query;
                navigator.permissions.query = function(permDescriptor) {
                    if (permDescriptor.name === 'camera' || permDescriptor.name === 'microphone') {
                        return Promise.resolve({ state: 'granted', onchange: null });
                    }
                    return originalQuery.call(this, permDescriptor);
                };
            }
            
            // Make getUserMedia more reliable
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                navigator.mediaDevices.getUserMedia = function(constraints) {
                    console.log('📷🎤 getUserMedia called with:', JSON.stringify(constraints));
                    return originalGetUserMedia.call(navigator.mediaDevices, constraints)
                        .then(stream => {
                            console.log('📷🎤 getUserMedia succeeded');
                            return stream;
                        })
                        .catch(err => {
                            console.error('📷🎤 getUserMedia error:', err.name, err.message);
                            // Forward the error but log it first for debugging
                            throw err;
                        });
                };
            }
        })();
        """
        
        let script = WKUserScript(source: webRTCScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }
    
    // Method to configure an existing WebView for WebRTC
    func configureWebViewForWebRTC(_ webView: WKWebView) {
        // Allow media playback without user interaction
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        webView.configuration.allowsAirPlayForMediaPlayback = true
        
        // Ensure JavaScript is enabled
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Configure JavaScript preferences
        if let webpagePrefs = webView.configuration.defaultWebpagePreferences {
            webpagePrefs.allowsContentJavaScript = true
        }
        
        // Add the WebRTC helper script
        enableWebRTCForWebView(webView)
    }
}
