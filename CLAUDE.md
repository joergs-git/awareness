# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Awareness** is a macOS menu bar app — a mindfulness/breathing timer that randomly blacks out the screen for a few seconds, forcing the user to pause, breathe, and reset. Think of it as a vipassana timer for computer work.

Repository: https://github.com/joergs-git/awareness
License: MIT

## Core Behavior

- Runs as a menu bar app with a yin-yang icon
- Randomly blacks out the screen for a configurable duration between configurable min/max intervals
- Detects active camera/microphone usage and skips blackout during calls/meetings
- Menu bar icon provides access to settings and quit

## Configurable Settings

- **Active time window** — hours during which interruptions occur (e.g. 08:00–19:00)
- **Blackout duration** — how long the screen stays blacked out (e.g. 10 seconds)
- **Blackout visual** — plain black, custom text, image, or short video animation
- **Random interval range** — min and max delay between interruptions (e.g. 5–60 minutes)
- **Gong sound** — play a sound when blackout starts (on/off)
- **Handcuffs mode** — if on, user cannot dismiss blackout early; if off, ESC or CMD-Q ends it immediately

## Platform Target

Primary target is macOS (native). iPhone/iPad and Windows versions may follow later.

## Development Notes

- This is a greenfield project — code structure will be established as development begins
- macOS menu bar apps typically use Swift with AppKit or SwiftUI
- Camera/microphone detection requires macOS AVFoundation or IOKit APIs
- Screen blackout overlay requires NSWindow with appropriate window level
