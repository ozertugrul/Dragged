# Recon map: Tangerine (macOS)

Scope: Gesture-based drag-and-drop file converter, radial wheel menu, tools wheel, local multi-format conversion engine, menu bar companion, and batch processing.
For: macOS power users, designers, developers, and content creators needing instant, offline, zero-upload file conversions directly from Finder.
Date: 2026-10-18

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | Instagram Reel (Metav3rse) | https://www.instagram.com/reels/DeoFIQkBaHz/ | Video demonstration of Shift+Drag radial wheel and features |
| 2 | Creator announcement (@th2049) | https://x.com/th2049 | Technical highlights and feature breakdowns |
| 3 | Product Website | https://tangerineformac.app | Official product page, supported formats, and capabilities |
| 4 | Mac App Store Listing | https://apps.apple.com/app/tangerine | System requirements and feature listings |

## Core loop

Drag any file from Finder while holding Shift (or over a drop target), select a format from a circular radial menu, and drop to instantly convert and save the file right next to the original without uploading to any server.

## Screens & Surfaces

| ID | surface | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Radial Wheel Overlay | Hold Shift while dragging a file in Finder / over Drop Pill | Circular pie menu for instant format selection | Donut sectors, format icons, center file badge | idle, hovered sector, active conversion, cancel |
| S02 | Tools Wheel Overlay | Hold Option + Shift while dragging a file | Circular tool menu for editing & optimization | Donut sectors (Compress, Scale, Grayscale, GIF, Mute) | idle, hovered tool, converting |
| S03 | Floating Drop Pill | Bottom center or notch of screen (toggleable) | Ambient drag-and-drop target to trigger wheel | Capsule pill, Tangerine icon, label | idle, drag hover, active |
| S04 | Menu Bar Companion | Top status bar icon (🍊) | Quick access menu, recent conversions, preferences | NSStatusItem, dropdown menu, recent files | idle, open, converting badge |
| S05 | Quick Converter Window | Menu bar -> "Open Converter Window..." (⌘O) | Full desktop app interface with batch drop & format pills | Drop zone, format grid, tools grid, recent list | empty, file loaded, converting, completed |
| S06 | Preferences & Settings | Menu bar -> "Preferences..." (⌘,) | Customization: save folder, quality, sounds, hotkeys | Tabbed settings, sliders, toggle switches | default, modified |

## Flows

```
F01 Quick Gesture Conversion
    Finder file drag -> Hold Shift -> S01 Radial Wheel blooms -> Hover format -> Drop file
    happy path clicks: 0 (drag-and-release only!)
    edge cases: unsupported format, destination file exists (rename with _1, _2), permission denied.

F02 Tool Action
    Finder file drag -> Hold Option+Shift -> S02 Tools Wheel -> Hover "Compress" / "Make GIF" -> Drop file
    happy path clicks: 0
    edge cases: video too large for GIF, non-video muted.

F03 Batch Conversion
    Select 10 files in Finder -> Drag into S05 Quick Converter Window -> Select "WebP" -> Click Convert All
    happy path clicks: 2
    edge cases: mixed file types in batch, partial failures handled with per-file status.

F04 Clipboard Conversion
    Copy image to clipboard -> Click Menu Bar (🍊) -> Click "Convert Clipboard to WebP"
    happy path clicks: 2
```

## Inferred Architecture & Data Model

```
FileCategory: image | video | audio | document | archive
FormatOption: id, name, ext, icon, category, description
ToolAction: id, name, icon, description, handler
ConversionTask: id, sourceURL, destinationURL, targetFormat, progress, status, date
UserSettings: saveDestinationMode (sameAsSource | custom), customFolderPath, imageQuality (1-100), playSound (bool), autoOpenInFinder (bool)
```

## Feature Matrix

See `features.csv`.
- Must: 12
- Should: 6
- Could: 4
- Skip: 0
