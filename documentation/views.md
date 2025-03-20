# Helios - Views Documentation

This document provides an overview of the SwiftUI views used in the Helios browser application.

## View Structure

Helios uses a hierarchical view structure organized around these key components:

1. **Root Views**: HeliosApp and ContentView
2. **Navigation Views**: SidebarView and DetailView 
3. **Tab-Related Views**: WebViewContainer, URLBarView, TabRow, etc.
4. **Settings Views**: SettingsView and its subviews
5. **Dialogs and Sheets**: Modal interfaces for adding content

## Root Views

### HeliosApp

The main entry point for the application, defined in `HeliosApp.swift`. This view:
- Configures the SwiftData schema and container
- Initializes default search engines
- Sets up multiple windows support
- Configures app commands and keyboard shortcuts
- Defines the settings window

### ContentView

The main container view that organizes the app layout, defined in `ContentView.swift`. This view:
- Establishes the NavigationSplitView for sidebar and detail panes
- Manages window state through WindowIdentifier
- Integrates with WindowManager for multi-window support
- Handles inspector panels like PageSettingsView

## Navigation Views

### SidebarView

The left navigation pane that shows workspaces and tabs, defined in `SidebarView.swift`. This view:
- Displays workspace selection
- Shows pinned tabs
- Allows workspace creation
- Provides navigation to settings

### DetailView

The main content area that displays web content, defined in `DetailView.swift`. This view:
- Contains the WebViewContainer
- Shows the URL bar and navigation controls
- Displays tab rows for the current workspace
- Handles tab switching

## Tab-Related Views

### WebViewContainer

Wraps the WKWebView and handles integration with SwiftUI, defined in `WebViewContainer.swift`. This view:
- Displays the web content
- Manages WebView lifecycle
- Handles size changes and system events

### WebView

A UIViewRepresentable wrapper for WKWebView, defined in `WebView.swift`. This view:
- Creates the actual WKWebView
- Handles coordination with SwiftUI

### URLBarView

The address bar and navigation controls, defined in `URLBarView.swift`. This view:
- Shows the current URL with editing capabilities
- Provides back/forward/refresh buttons
- May include security indicators

### TabRow

Displays and manages browser tabs, defined in `TabRow.swift`. This view:
- Shows tab titles and favicons
- Handles tab selection
- Provides tab close buttons
- Supports drag-and-drop reordering

### PinnedTabsGrid

Displays pinned tabs in a grid layout, defined in `PinnedTabsGrid.swift`. This view:
- Shows pinned tabs with favicons
- Handles selection of pinned tabs
- Supports drag-and-drop for reordering

### DraggableTabSection

A component for managing draggable tab collections, defined in `DraggableTabSection.swift`. This view:
- Provides consistent drag-and-drop behavior
- Organizes tabs of a specific type

## Settings Views

### SettingsView

The main settings view with categories, defined in `SettingsView.swift`. This view:
- Provides navigation to different settings categories
- May include general browser settings

### ProfileSettingsView

Manages profile-specific settings, defined in `ProfileSettingsView.swift`. This view:
- Shows profile details
- Allows editing profile properties
- Manages user agent settings
- Controls privacy settings

### ProfileDetailView

Shows detailed view of a profile, defined in `ProfileDetailView.swift`. This view:
- Displays profile information
- May show statistics
- Handles profile-specific actions

### SearchEngineSettingsView

Manages search engine configuration, defined in `SearchEngineSettingsView.swift`. This view:
- Lists configured search engines
- Allows setting a default engine
- Supports adding/editing/removing engines

### WebsitesSettingsView

Manages site-specific settings, defined in `WebsitesSettingsView.swift`. This view:
- Shows configured site settings
- Allows editing permissions by site
- May include storage usage information

### PageSettingsView

Shows and edits settings for the current page, defined in `PageSettingsView.swift`. This view:
- Displays current site permissions
- Allows changing permissions for the active site
- Provides content control options

## Dialogs and Sheets

### AddProfileSheet

Modal interface for creating a new profile, defined in `AddProfileSheet.swift`. This view:
- Collects profile information
- Validates input
- Creates new profiles

### CreateWorkspaceView

Interface for creating a new workspace, defined in `CreateWorkspaceView.swift`. This view:
- Collects workspace name and icon
- Allows selecting a profile
- Creates new workspaces

### IconPicker

A component for selecting icons, defined in `IconPicker.swift`. This view:
- Displays available icons in a grid
- Supports selection
- May include categorization

### AddSearchEngineView

Interface for adding a custom search engine, defined in `AddSearchEngineView.swift`. This view:
- Collects search engine details
- Validates URL patterns
- Creates new search engine entries

### PermissionRequestView

Shows permission requests from websites, defined in `PermissionRequestView.swift`. This view:
- Displays the permission request details
- Provides allow/deny options
- May include "remember decision" options

## Supporting Views

### PermissionRow / OptionalPermissionRow

Consistent components for displaying permission settings, defined in `PermissionRow.swift` and `OptionalPermissionRow.swift`. These views:
- Show a permission label and description
- Provide controls for changing the permission state
- Handle optional values

### SoundRow

A specialized row for sound permission control, defined in `SoundRow.swift`. This view:
- Shows sound settings
- Provides a picker for sound control options

### ProfileRow

Displays a profile in a list, defined in `ProfileRow.swift`. This view:
- Shows profile name and icon
- May include selection handling

### FaviconView

A component for displaying website favicons, not explicitly listed but likely exists. This view:
- Shows favicon images
- Handles loading and caching
- Provides fallback icons

## Integration with ViewModels

Most views accept and interact with appropriate view models:
- ContentView and major views take a BrowserViewModel instance
- Permission-related views connect to PermissionManager
- Settings views often connect directly to SwiftData through @Query or @Environment(\.modelContext)
