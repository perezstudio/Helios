# Helios - Application Architecture

This document describes the overall architecture of the Helios browser application.

## Architectural Pattern

Helios follows the MVVM (Model-View-ViewModel) architectural pattern:

1. **Models**: SwiftData models define the data structure
2. **Views**: SwiftUI views handle the user interface
3. **ViewModels**: Manage application state and business logic

The app also incorporates aspects of these architectural principles:
- **Dependency Injection**: ViewModels are injected into views
- **Data Flow**: Unidirectional data flow using SwiftUI's binding mechanism
- **Observer Pattern**: Notification-based communication between components

## Key Components and Relationships

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  SwiftUI Views  │◄────┤   ViewModels    │◄────┤  SwiftData      │
│                 │     │                 │     │  Models         │
└────────┬────────┘     └────────┬────────┘     └─────────────────┘
         │                       │                       ▲
         │                       │                       │
         ▼                       ▼                       │
┌─────────────────┐     ┌─────────────────┐             │
│                 │     │                 │             │
│  WebKit Views   │◄────┤ WebKit Config   │─────────────┘
│                 │     │ & Sessions      │   (Persistence)
└─────────────────┘     └─────────────────┘
```

## Data Flow

1. **User Interaction Flow**:
   - User interacts with SwiftUI views
   - Views call methods on ViewModels
   - ViewModels update their state
   - SwiftUI reactively updates the UI based on the new state

2. **Persistence Flow**:
   - ViewModels modify SwiftData models
   - Changes are saved to the SwiftData store
   - SwiftUI views using @Query automatically refresh

3. **Web Content Flow**:
   - ViewModels manage WebKit configurations
   - WebViewContainer/WebView display web content
   - WebViewNavigationDelegate captures events
   - Events flow back to ViewModels for state updates

## Component Responsibilities

### SwiftUI Views

- Present user interface
- Capture user input
- Display web content
- Provide navigation between app sections

### ViewModels

- Maintain application state
- Process user input
- Manage WebKit configurations
- Handle business logic
- Coordinate between components

### SwiftData Models

- Define data structure
- Provide persistence
- Enable data querying
- Support relationship management

### WebKit Integration

- Render web content
- Handle navigation events
- Manage web sessions
- Process permissions

## Key Interactions

### Browser Navigation

1. User enters URL in URLBarView
2. URLBarView updates urlInput in BrowserViewModel
3. handleUrlInput() processes the input
4. BrowserViewModel gets WebView for current tab
5. WebView loads the requested URL
6. WebViewNavigationDelegate captures events
7. Tab title and URL are updated in the model
8. UI updates to reflect the new state

### Tab Management

1. User requests a new tab
2. BrowserViewModel.addNewTab() creates Tab model
3. Tab is added to current Workspace
4. WebView is created with appropriate configuration
5. UI updates to show the new tab

### Profile Switching

1. User selects a different profile
2. BrowserViewModel.switchToProfile() is called
3. Old profile's WebViews are cleaned up
4. New profile's WebViews are created
5. Current tab and workspace are updated
6. UI refreshes to reflect the new profile's content

## Multi-Window Support

The application supports multiple windows through:

1. **WindowManager**: 
   - Tracks active windows with UUIDs
   - Maintains window registry

2. **Window-Specific State**:
   - Each window has a WindowIdentifier
   - BrowserViewModel maintains dictionaries mapping:
     - Window IDs to selected tabs
     - Window IDs to selected workspaces

3. **FocusedValues**:
   - WindowIdKey provides access to window ID in commands

## Permission Management

The permission system works through:

1. WebKit permission requests trigger PermissionManager
2. PermissionManager queues the request
3. UI shows PermissionRequestView
4. User decision is passed back to WebKit
5. Decision is stored in SiteSettings for future visits

## Session Isolation

Helios provides strong isolation between profiles through:

1. **Process Pool Isolation**:
   - Each profile has its own WKProcessPool
   - Ensures JavaScript contexts cannot access other profiles

2. **Data Store Isolation**:
   - Each profile has its own WKWebsiteDataStore
   - Prevents cookie and storage sharing

3. **Directory Isolation**:
   - Profile data stored in separate directories
   - WebKitDirectoryHelper manages this separation

4. **Custom User Agent**:
   - Each profile can have a distinct user agent
   - Helps with site-specific behavior
