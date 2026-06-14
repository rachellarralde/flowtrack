# FlowTrack Pro

FlowTrack now includes a native macOS menu bar app alongside the original static web files.

## Features

- ⏱️ **Menu Bar Timer** - Start, pause, stop, and reset work sessions from the macOS menu bar
- 📁 **Project Management** - Create and switch between projects quickly
- 📝 **Task Notes** - Add a short note for the current work session
- 📊 **Recent Sessions** - Review the latest tracked sessions in the popover
- 💾 **Local Saving** - Projects and sessions are saved on your Mac automatically
- 🌐 **Original Web Version** - The simple HTML/CSS/JS version is still in the repo

## Open the macOS App

1. Open [FlowTrackMenuBar.xcodeproj](/Users/witchaudio/Developer/github-work/flowtrack/FlowTrackMenuBar.xcodeproj)
2. Choose the `FlowTrackMenuBar` scheme
3. Press the Run button in Xcode
4. Look for the timer icon in your macOS menu bar

You can also launch the built app directly from:

- [Build/Build/Products/Debug/FlowTrackMenuBar.app](/Users/witchaudio/Developer/github-work/flowtrack/Build/Build/Products/Debug/FlowTrackMenuBar.app)

## Project Structure

- `FlowTrackMenuBar.xcodeproj` - Xcode project for the native macOS app
- `FlowTrackMenuBar/` - SwiftUI app source files
- `FlowTrackMenuBarTests/` - Unit tests for timer and project logic
- `index.html`, `app.js`, `style.css` - Original web app files

## Using the Menu Bar App

1. Add a project
2. Select it from the project menu
3. Type what you're working on
4. Press `Start`
5. Use `Pause`, `Stop`, or `Reset` as needed

## Data Storage

- The original web app stores data in browser `localStorage`
- The macOS app stores data locally in Application Support on your Mac
