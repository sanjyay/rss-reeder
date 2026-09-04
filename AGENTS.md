# AGENTS.md

Instructions for coding agents working on the Omarchy RSS-Reeder plugin (`io.github.sanjyay.rss-reeder`).

## Architecture

The RSS-Reeder plugin is structured into three primary layers:

1. **Bar Entry (`BarWidget.qml`)**:
   - Manages widget lifecycle, background polling timer, and process executions (`curl`, `mkdir`, `omarchy-file-select`).
   - Owns persistence for widget settings (`subscriptions`, `feedUrls`, `pollIntervalMinutes`, `maxItemsPerFeed`, `itemsPerPage`, `retentionDays`, `barSection`, `readIdentities`).
   - Persists state and read identities to `$XDG_DATA_HOME/omarchy-rss-reeder/state.json` (with automatic migration from `$XDG_DATA_HOME/omarchy-rss-plugin/state.json`).
   - Manages OPML file selection through `omarchy-file-select` and file reading processes.

2. **User Interface (`Panel.qml`)**:
   - Provides the interactive surface for viewing unread/read items, filtering, paginating, and managing settings.
   - Settings views include Feeds management, Options, and Share & Import.
   - Hosts the OPML import UI (both "Import OPML file" file chooser button and text field for pasting OPML/JSON/URL payloads).
   - Provides clear user feedback (`shareStatus`) reporting imported feed counts or errors.

3. **Pure Logic & Model (`Model.js`)**:
   - Parses RSS 2.0 and Atom 1.0 feeds.
   - Parses OPML documents (`parseOpml`) and share payloads (`parseSharePayload`), extracting valid HTTPS feed URLs.
   - Handles XML entity decoding in feed URLs (e.g., `&amp;` to `&`).
   - Manages feed list merging, deduplication, item identity extraction, unread counts, and pagination.

## OPML Import Feature

- **Architecture & Ownership**:
  - The persistent import controller lives in `BarWidget.qml`, surviving transient popup closes or focus changes.
  - `Panel.qml` only emits import requests via `root.hostWidget.requestOpmlFileImport()` and displays the persisted `lastImportResult` / `shareStatus`.
- **File Selection & URL Handling**:
  - Invokes `omarchy-file-select --title "Select OPML file" --extensions "opml xml"` via desktop portal integration.
  - Decodes `file://` URLs and percent-encoded paths (including spaces, `#`, `%`, parentheses, and Unicode) via `Model.filePathFromUrl()`.
- **File Validation & Security**:
  - Validates that the selected path is a single regular file (rejects directories, devices, and special files).
  - Enforces a 5 MiB file size limit before reading.
  - Safely reads file contents using a non-blocking process without shell interpolation.
- **Feed Management & Persistence**:
  - Extracts all `xmlUrl` attributes (flat or nested in folder outlines), filters to HTTPS-only URLs, and merges them with existing feed URLs without duplicates.
  - Automatically persists merged feed lists to plugin settings, updates `lastImportResult`, and triggers an immediate fetch of all configured feeds.
  - Displays import result messages during the active session and automatically clears them once the plugin is closed.
- **Verification**: Validates runtime QML, syntax checking with `qmllint`, manifest validation with `omarchy plugin validate .`, and unit test coverage via `node --test tests/*.mjs`.

## Development & Testing

- Run unit tests:
  ```bash
  node --test tests/*.mjs
  ```
- Lint QML files:
  ```bash
  qmllint -I /usr/share/omarchy/shell/ BarWidget.qml Panel.qml
  ```
- Validate manifest:
  ```bash
  omarchy plugin validate .
  ```
- Rescan / reload live shell:
  ```bash
  omarchy-shell shell rescanPlugins
  ```
