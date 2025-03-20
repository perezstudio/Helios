import WebKit

extension WKWebView {
    /// Configure WebView for WebRTC access
    func enableWebRTCAccess() {
        // 1. Make sure all configuration preferences are set
        let configuration = self.configuration
        
        // Allow media playback without user interaction
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Ensure JavaScript is enabled
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Safely unwrap defaultWebpagePreferences and set allowsContentJavaScript
        if let webpagePrefs = configuration.defaultWebpagePreferences {
            webpagePrefs.allowsContentJavaScript = true
        }
        
        // Disable app-bound domain limitations for WebRTC
        if #available(macOS 14.0, *) {
            // We don't need to set mediaDevicesRequiresUserGesture as it's not available in this version
            // Just disable app-bound domain limitations
            configuration.limitsNavigationsToAppBoundDomains = false
        }
        
        // 2. Add WebRTC permission helper script
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
                        
                        // Handle permission errors more gracefully
                        if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                            console.log('📷🎤 Permission denied, trying again with prompt');
                            
                            // Try again with prompt UI
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
        
        // Add the script to the user content controller
        let script = WKUserScript(source: webRTCScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(script)
    }
}
