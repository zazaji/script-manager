# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ScriptManager** is a native macOS SwiftUI application that automatically generates GUI interfaces from CLI scripts (Bash, Python, Node.js, Ruby). Scripts use `@Param` comments to define parameters that get converted into UI controls.

## Key Architecture

- **Models**: `ScriptModels.swift` - ScriptItem, ScriptParameter, ScriptMetadata, ExecutionSession
- **Services**: ScriptParserService (parses @Param comments), ScriptExecutionService (PTY-based execution), WorkspaceManager (file monitoring)
- **ViewModels**: WorkspaceViewModel (singleton, manages scripts/applications), ScriptDetailViewModel (per-script state), TerminalManager (execution sessions), LauncherViewModel (quick launcher)
- **Views**: NavigationSplitView with Sidebar (4 tabs: Frequent/Custom/Workspace/Applications) + Detail (config/code/split view) + Terminal panel
- **Core**: GlobalHotkeyManager (Carbon-based global shortcuts), PermissionManager (FDA detection), AppStateManager (UserDefaults + Security-Scoped Bookmarks)

## Building & Running

- Open `ScriptManager.xcodeproj` in Xcode
- Build with Cmd+R or Product > Run
- Requires Full Disk Access for workspace file operations

## Key Patterns

- Singletons via `shared` static property for global state
- ObservableObject for reactive UI updates
- PTY allocation via `posix_openpt` + `grantpt` for terminal execution
- Security-Scoped Bookmarks for persistent workspace access
- Multi-probe FDA detection bypassing TCC cache issues

## Commands

- `ScriptExecutionService.execute()` - runs a script with arguments
- `ScriptParserService.parse()` - async parses script metadata
- `WorkspaceManager.createScript()` - creates new script files
- `TerminalManager.addSession()` - starts terminal session

## Critical Notes

- App runs outside macOS sandbox for full terminal access
- Uses `/usr/bin/script` wrapper for controlling terminal support (sudo password prompts)
- Pinyin search via CFStringTransform for Chinese text matching
- Form data binding uses local @State to prevent race conditions on text input
