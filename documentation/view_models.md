# Helios - View Models Documentation

This document provides an overview of the view models used in the Helios browser application. These view models manage the application state and logic.

## Overview

Helios follows the MVVM (Model-View-ViewModel) architecture pattern, with the following key view models:

1. **BrowserViewModel**: The primary view model managing browser state and operations
2. **SessionManager**: Manages WebKit configurations and browsing sessions
3. **PermissionManager**: Handles permission requests and responses
4. **WebKitDirectoryHelper**: Utility for WebKit data storage management
5. **WindowManager**: Manages multiple windows and their state

## BrowserViewModel

The `BrowserViewModel` class serves as the primary view model for the application, managing most of the browser's functionality.

### Core Functionality

- Tab management (create, delete, update)
- Workspace management
- URL input handling and navigation
- WebView creation and management
- Tab state tracking (loading, etc.)
- Profile switching

### Key Properties

- `modelContext`: SwiftData context for persistence
- `urlInput`: Current URL text input
- `currentURL`: Currently loaded URL
- `workspaces`: List of available workspaces
- `currentWorkspace`: Currently active workspace
- `currentTab`: Currently displayed tab
- `pinnedTabs`, `bookmarkTabs`, `normalTabs`: Filtered tab collections

### WebView Management

The BrowserViewModel maintains multiple collections to track WebViews:
- `webViewsByProfile`: Maps profile IDs to a collection of tab WebViews
- `navigationDelegatesByProfile`: Maps delegates for WebView navigation
- `webViewObservers`: Notification observers for WebViews

### Window-Specific State

The view model uses dictionaries to track window-specific states:
- `tabSelectionsByWindow`: Currently selected tab for each window
- `workspaceSelectionsByWindow`: Currently selected workspace for each window

### Key Methods

- `addNewTab()`: Creates a new browser tab
- `togglePin()`: Toggles a tab between pinned and normal state
- `toggleBookmark()`: Toggles a tab between bookmarked and normal state
- `deleteTab()`: Removes a tab
- `handleUrlInput()`: Processes URL bar input
- `selectTab()`: Changes the selected tab
- `setCurrentWorkspace()`: Changes the current workspace
- `switchToProfile()`: Changes the active profile
- `ensureWebView()`: Creates or retrieves a WebView for a tab
- `getPageSettings()`: Retrieves site-specific settings

## SessionManager

The `SessionManager` class manages WebKit configurations, process pools, and data stores to ensure proper session isolation between profiles.

### Core Functionality

- Creates isolated WebKit configurations for profiles
- Manages process pools for JavaScript context isolation
- Configures data stores for cookies and site data
- Sets up profile-specific user scripts

### Key Properties

- `processPoolsByProfile`: Maps profile IDs to WKProcessPool objects
- `dataStoresByProfile`: Maps profile IDs to WKWebsiteDataStore objects
- `configurationsByProfile`: Maps profile IDs to WKWebViewConfiguration objects

### Key Methods

- `getConfiguration(for:)`: Returns a profile-specific WebKit configuration
- `getDataStore(for:)`: Returns a profile-specific data store
- `cleanupProfile(_:)`: Removes all data for a profile
- `invalidateConfiguration(for:)`: Forces configuration recreation

## PermissionManager

The `PermissionManager` singleton handles website permission requests and user responses.

### Core Functionality

- Manages permission request queue
- Presents permission requests to the user
- Processes permission responses
- Updates site settings based on user decisions

### Key Properties

- `pendingRequests`: Queue of permission requests
- `activeRequest`: Currently displayed permission request

### Key Types

- `PermissionRequest`: Structure representing a permission request
- `PermissionFeature`: Enum for different permission types (camera, location, etc.)

### Key Methods

- `requestPermission(for:permission:)`: Queues a new permission request
- `handlePermissionResponse(_:for:in:)`: Processes user response to a permission request

## WebKitDirectoryHelper

The `WebKitDirectoryHelper` class provides utility functions for managing WebKit data storage.

### Core Functionality

- Sets up profile-specific data directories
- Creates custom data stores for profiles
- Cleans up profile data when needed

### Key Methods

- `setupCustomDataStore(for:)`: Creates a profile-specific data store
- `clearProfileData(for:)`: Removes all data for a profile

## Integration Between View Models

The view models work together to provide a cohesive experience:

1. `BrowserViewModel` is the primary coordination point
2. It uses `SessionManager` to create isolated WebView configurations
3. `PermissionManager` intercepts and handles permission requests
4. `WebKitDirectoryHelper` manages the file system storage for web data
5. `WindowManager` (not detailed above) coordinates multiple window state

This separation of concerns allows for better testability and maintenance of the codebase.
