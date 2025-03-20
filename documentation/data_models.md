# Helios - Data Models Documentation

This document provides an overview of the data models used in the Helios browser application. These models are defined using SwiftData for persistent storage.

## Overview

Helios uses SwiftData to manage its data persistence with the following primary model classes:

1. **Profile**: Represents a user profile with isolated browsing data
2. **Workspace**: A collection of tabs with associated settings
3. **Tab**: An individual browser tab
4. **HistoryEntry**: Represents a page visit in browsing history
5. **SearchEngine**: Defines a search engine configuration
6. **SiteSettings**: Stores website-specific permissions and settings

## Model Relationships

```
Profile
  ├── Workspaces[]
  │     └── Tabs[]
  ├── History[]
  ├── DefaultSearchEngine
  └── SiteSettings[]
```

## Model Definitions

### Profile

The Profile model represents a user profile with isolated browsing data, settings, and history.

**Properties**:
- `id`: UUID - Unique identifier (with unique attribute)
- `name`: String - Display name
- `workspaces`: [Workspace] - Associated workspaces
- `history`: [HistoryEntry] - Browsing history
- `defaultSearchEngine`: SearchEngine? - Default search engine
- `userAgent`: String? - Custom user agent string
- `version`: Int - Version for migration purposes
- `siteSettings`: [SiteSettings] - Website-specific settings

**Computed Properties**:
- `pinnedTabs`: [Tab] - Aggregated pinned tabs from all workspaces
- `userAgentType`: UserAgent - Enum conversion of the user agent string

### Workspace

The Workspace model represents a collection of tabs with associated metadata.

**Properties**:
- `id`: UUID - Unique identifier
- `name`: String - Display name
- `icon`: String - Icon identifier
- `color`: String - Legacy color storage
- `colorTheme`: ColorTheme - Color theme enum
- `tabs`: [Tab] - Associated tabs
- `profile`: Profile? - Parent profile

### Tab

The Tab model represents an individual browser tab with its state.

**Properties**:
- `id`: UUID - Unique identifier
- `title`: String - Page title
- `url`: String - Current URL
- `type`: TabType - Tab type (normal, pinned, bookmark)
- `workspace`: Workspace? - Parent workspace
- `faviconData`: Data? - Cached favicon
- `webViewId`: UUID? - Associated WebView identifier
- `bookmarkedUrl`: String? - Original URL for bookmarked tabs
- `displayOrder`: Int - Tab ordering position

**Computed Properties**:
- `profile`: Profile? - Shortcut to access parent profile
- `originalUrl`: String - Returns bookmarked URL if applicable

### SearchEngine

The SearchEngine model represents a search provider configuration.

**Properties**:
- `id`: UUID - Unique identifier
- `name`: String - Display name
- `shortcut`: String - Keyword for quick access
- `searchUrl`: String - URL template with %s placeholder
- `isBuiltIn`: Bool - Flag for built-in engines
- `profiles`: [Profile]? - Profiles using this as default

**Static Properties**:
- `defaultEngines`: [SearchEngine] - Pre-defined search engines

### SiteSettings

The SiteSettings model stores website-specific permissions and settings.

**Properties**:
- `id`: UUID - Unique identifier
- `hostPattern`: String - Domain pattern to match
- `profile`: Profile? - Parent profile
- `usageSize`: Int64 - Data usage tracking
- Various permission properties (camera, location, etc.) of type `PermissionState?`

**Methods**:
- `appliesTo(url:)` - Checks if settings apply to a given URL

## Enumerations

### TabType
- `pinned` - Tab pinned to the tab bar
- `bookmark` - Tab that represents a bookmark
- `normal` - Standard tab

### ColorTheme
- Various color options (`blue`, `red`, `green`, etc.)
- Provides color mapping to SwiftUI Color values

### UserAgent
- Preset user agent strings (`safari`, `chrome`, `firefox`, `edge`)
- Each with associated browser identifier string

### PermissionState
- `ask` - Prompt user for permission
- `allow` - Always allow
- `block` - Always block

### SoundState
- `automatic` - Default sound behavior
- `allow` - Always allow sound
- `mute` - Always mute

## Migration Plans

The app includes migration plans for evolving model schemas:
- `AppMigrationPlan` - Overall app migration
- `ProfileMigrationPlan` - Profile-specific migrations
