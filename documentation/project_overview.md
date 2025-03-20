# Helios Browser - Project Overview

## Introduction

Helios is a macOS web browser application built using SwiftUI and SwiftData for persistence. The app provides a modern browsing experience with support for multiple workspaces, profiles, and tab management.

## Project Structure

The Helios project follows a standard SwiftUI application structure with the following key components:

```
/Helios
├── HeliosApp.swift           # Main entry point for the application
├── Assets.xcassets           # App assets and resources
├── Models/                   # SwiftData model definitions
├── Views/                    # SwiftUI views
├── ViewModel/                # View models and business logic
├── CustomStyles/             # Custom UI styles
└── Preview Content/          # Preview assets
```

## Key Technologies

- **SwiftUI**: Used for building the user interface
- **SwiftData**: Used for persistence and data modeling
- **WebKit**: Provides the web rendering engine (WKWebView)

## Application Architecture

Helios follows the MVVM (Model-View-ViewModel) architecture:

1. **Models**: SwiftData models define the data structure of the application
2. **Views**: SwiftUI views handle the visual presentation
3. **ViewModels**: Manage the state and business logic, and act as a bridge between views and models

## Key Features

- Multiple workspace support
- Profile-based browsing with isolated sessions
- Tab management (pinned, bookmarked, and regular tabs)
- Custom site permissions
- Search engine management
- Browsing history tracking

## Core Concepts

### Profiles
Profiles are isolated browsing contexts with their own settings, history, and permissions. Each profile manages its own set of workspaces.

### Workspaces
Workspaces are collections of tabs that can be organized by the user. Each workspace belongs to a profile.

### Tabs
Tabs represent individual web pages that can be of different types:
- Normal tabs
- Pinned tabs
- Bookmarked tabs

### Site Settings
Site-specific settings that control permissions like camera access, microphone, location, and other features on a per-site basis.

## Persistence

The app uses SwiftData for persistence with the following main entities:
- Profile
- Workspace
- Tab
- HistoryEntry
- SearchEngine
- SiteSettings

## Session Management

The app provides isolated browsing sessions through the SessionManager class, which manages WebKit configurations, process pools, and data stores for each profile.

## Window Management

The app supports multiple windows through the WindowManager class, which tracks active windows and their associated state.
