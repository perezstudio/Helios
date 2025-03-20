# Helios - WebView Management

This document details the WebView management system in the Helios browser application, which is a central component of the browser functionality.

## Overview

Helios uses WebKit's WKWebView as its web rendering engine. The app implements a sophisticated WebView management system that provides:

1. **Profile Isolation**: Ensures complete separation between browsing profiles
2. **Efficient Resource Usage**: Manages WebView lifecycle to optimize memory and CPU usage
3. **State Persistence**: Maintains WebView state across app launches
4. **Permission Management**: Handles website permission requests

## Key Components

### WebView Creation and Management

The WebView management system is primarily implemented in the `BrowserViewModel` class, with these key methods:

- `ensureWebView(for:)`: Creates or retrieves a WebView for a tab
- `getWebView(for:)`: Returns the WebView associated with a tab
- `createWebView(for:)`: Creates a new WebView with proper configuration
- `cleanupWebView(for:)`: Properly disposes of a WebView

The system maintains collections to track WebViews:

```swift
private var webViewsByProfile: [UUID: [UUID: WKWebView]] = [:]
private var navigationDelegatesByProfile: [UUID: [UUID: WebViewNavigationDelegate]] = [:]
private var webViewObservers: [UUID: NSObjectProtocol] = [:]
```

This structure allows Helios to:
- Store WebViews by profile ID and tab ID
- Locate the correct WebView quickly
- Clean up resources when tabs are closed

### WebView Configuration

WebView configurations are managed by the `SessionManager` class, which:

1. Creates profile-specific WKWebViewConfiguration objects
2. Manages process pools for proper isolation
3. Configures data stores for cookies and site data
4. Sets up user scripts for each profile

```swift
func getConfiguration(for profile: Profile?) -> WKWebViewConfiguration {
    if let profile = profile {
        return getProfileConfiguration(for: profile)
    } else {
        return createIsolatedConfiguration()
    }
}
```

### WebViewNavigationDelegate

The `WebViewNavigationDelegate` class handles WebView navigation events:

- Title changes
- URL changes
- Navigation start/finish
- Permission requests
- New window creation

It serves as the connection point between WebKit events and the app's state.

### WebView Lifecycle

The WebView lifecycle follows these stages:

1. **Creation**: 
   - Triggered by `ensureWebView(for:)` 
   - Uses SessionManager to get configuration
   - Creates WKWebView instance with proper settings
   - Sets up delegates and observers

2. **Usage**:
   - WebView loads content based on tab URL
   - Navigation events update tab state
   - Permission requests are intercepted and handled

3. **Cleanup**:
   - WebView is stopped when tab is closed
   - Resources are freed
   - Observers are removed

4. **Profile Switching**:
   - All WebViews for the old profile are cleaned up
   - New WebViews are created for the new profile
   - State is restored from persistence

## Profile Isolation

A key feature of Helios is strong isolation between profiles, implemented through:

### Process Pool Isolation

Each profile has its own WKProcessPool, ensuring JavaScript contexts cannot interact between profiles:

```swift
let processPool = WKProcessPool() // New process pool for each profile
config.processPool = processPool
```

### Data Store Isolation

Each profile has a dedicated WKWebsiteDataStore:

```swift
let dataStore = WebKitDirectoryHelper.setupCustomDataStore(for: profile)
config.websiteDataStore = dataStore
```

### Directory Structure

Profile data is stored in isolated directories:

```
ApplicationSupport/
└── Helios/
    └── Profiles/
        ├── [Profile-UUID-1]/
        │   └── (WebKit data)
        └── [Profile-UUID-2]/
            └── (WebKit data)
```

The `WebKitDirectoryHelper` class manages this directory structure.

## Permission Handling

Website permissions are managed through a multi-step process:

1. Permission requests from WebKit are intercepted by WebViewNavigationDelegate
2. Requests are forwarded to PermissionManager
3. PermissionManager shows UI for user decision
4. User decision is stored in SiteSettings
5. Response is passed back to WebKit

This system allows permissions to be:
- Requested per site
- Remembered for future visits
- Managed differently across profiles

## State Restoration

The WebView state is persisted through SwiftData:

1. Tab objects store URL, title, and other state
2. On app launch, WebViews are recreated
3. Content is reloaded based on saved URLs

## Memory Management

To optimize memory usage, Helios:

1. Creates WebViews only when needed
2. Properly cleans up unused WebViews
3. Handles process pool sharing for efficiency
4. Uses notification observers for state synchronization

## Special Handling for Tab Types

Different tab types have specialized WebView handling:

- **Normal Tabs**: Standard handling, created as needed
- **Pinned Tabs**: May be pre-loaded for quick access
- **Bookmarked Tabs**: Special URL handling to maintain bookmarked state

## Future Considerations

The WebView management system could be enhanced with:

1. Background tab suspension for memory optimization
2. More sophisticated caching strategies
3. Enhanced isolation features for private browsing
