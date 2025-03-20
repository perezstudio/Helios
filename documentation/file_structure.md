# Helios - File Structure Documentation

This document provides an overview of the file structure of the Helios browser application.

## Root Project Structure

```
/Developer/Helios/
├── Helios/                    # Main application folder
├── Helios.xcodeproj/          # Xcode project files
├── .git/                      # Git repository
└── documentation/             # Project documentation
```

## Application Folder Structure

```
/Helios/
├── HeliosApp.swift            # Main app entry point
├── Info.plist                 # App configuration
├── Helios.entitlements        # App entitlements
├── Assets.xcassets/           # App resources and images
├── Preview Content/           # Xcode preview resources
├── Models/                    # Data models
├── Views/                     # UI components
├── ViewModel/                 # View models and logic
└── CustomStyles/              # Custom UI style definitions
```

## Models Directory

```
/Models/
├── AppMigrationPlan.swift     # SwiftData migration plan
├── CodableTab.swift           # Serializable tab model
├── Enums.swift                # Common enumerations
├── HistoryEntry.swift         # Browsing history model
├── IconModel.swift            # Icon resources model
├── Profile.swift              # User profile model
├── ProfileMigrationPlan.swift # Profile migration logic
├── SearchEngine.swift         # Search engine model
├── SiteSettings.swift         # Website settings model
├── SiteSettingsManager.swift  # Settings management
├── Tab.swift                  # Browser tab model
└── Workspace.swift            # Workspace model
```

## Views Directory

```
/Views/
├── ContentView.swift          # Main container view
├── DetailView.swift           # Main content area
├── SidebarView.swift          # Navigation sidebar
├── WebView.swift              # WKWebView wrapper
├── WebViewContainer.swift     # WebView container
├── WebViewNavigationDelegate.swift # WebKit navigation handling
├── URLBarView.swift           # Address bar
├── TabRow.swift               # Tab row display
├── PinnedTabsGrid.swift       # Pinned tabs display
├── DraggableTabSection.swift  # Draggable tab section
│
├── # Settings Views
├── SettingsView.swift         # Main settings view
├── ProfileSettingsView.swift  # Profile settings
├── ProfileDetailView.swift    # Profile details
├── SearchEngineSettingsView.swift # Search engine settings
├── WebsitesSettingsView.swift # Site settings management
├── PageSettingsView.swift     # Per-page settings
│
├── # Dialog/Modal Views
├── AddProfileSheet.swift      # Add profile dialog
├── CreateProfileView.swift    # Profile creation
├── CreateWorkspaceView.swift  # Workspace creation
├── AddSearchEngineView.swift  # Add search engine
├── AddSitePatternSheet.swift  # Add site pattern
├── PermissionRequestView.swift # Permission request dialog
│
├── # Components
├── IconPicker.swift           # Icon selection component
├── PermissionRow.swift        # Permission row component
├── OptionalPermissionRow.swift # Optional permission row
├── PermissionsForm.swift      # Permissions form
├── ProfileRow.swift           # Profile row component
├── SoundRow.swift             # Sound control component
└── WindowManager.swift        # Window management
```

## ViewModel Directory

```
/ViewModel/
├── BrowserViewModel.swift     # Main browser logic
├── SessionManager.swift       # WebKit session management
├── PermissionManager.swift    # Permission handling
└── WebKitDirectoryHelper.swift # WebKit data directory management
```

## File Descriptions

### Core Application Files

- **HeliosApp.swift**: The main entry point for the application. Configures SwiftData, sets up the scene, and initializes default data.

- **ContentView.swift**: The main container view that sets up the NavigationSplitView for the sidebar and detail panes.

### Model Files

- **Profile.swift**: Defines the user profile model with properties for name, workspaces, history, and settings.

- **Workspace.swift**: Represents a collection of tabs with associated metadata like name, icon, and color theme.

- **Tab.swift**: Represents an individual browser tab with properties for URL, title, and type.

- **SiteSettings.swift**: Stores website-specific permissions and settings like camera access, location, etc.

- **SearchEngine.swift**: Defines search engine configurations and includes default engines.

- **Enums.swift**: Contains enumerations used throughout the app, including TabType, ColorTheme, and PermissionState.

### ViewModel Files

- **BrowserViewModel.swift**: The primary view model that manages browser state, tab operations, URL handling, and WebView management.

- **SessionManager.swift**: Manages WebKit configurations and session data to ensure proper isolation between profiles.

- **PermissionManager.swift**: Handles website permission requests and user responses.

- **WebKitDirectoryHelper.swift**: Utility for managing WebKit data storage directories.

### Key View Files

- **DetailView.swift**: The main content area that displays web content and tab interface.

- **SidebarView.swift**: The navigation sidebar showing workspaces and navigation options.

- **WebViewContainer.swift**: Container for the WebView that handles integration with SwiftUI.

- **WebViewNavigationDelegate.swift**: Handles WebKit navigation events and callbacks.

- **SettingsView.swift**: The main settings interface with access to various configuration options.

## File Dependencies and Relationships

The Helios application follows a clear dependency hierarchy:

1. **View Dependencies**:
   - Views depend on ViewModels for data and logic
   - Views may use other Views as components
   - Views observe @Observable model changes

2. **ViewModel Dependencies**:
   - BrowserViewModel depends on SessionManager for WebKit configuration
   - BrowserViewModel interacts with PermissionManager for permissions
   - ViewModels depend on SwiftData models for persistence

3. **Model Dependencies**:
   - Models define relationships between entities
   - Models may have migration plans for schema evolution
   - Models are mostly independent of views and view models

## SwiftData Schema

The SwiftData schema is defined in HeliosApp.swift:

```swift
let schema = Schema([
    Profile.self,
    Workspace.self,
    Tab.self,
    HistoryEntry.self,
    SearchEngine.self
])
```

This schema provides the foundation for the app's persistence layer.
