# Take a Break (dms-take-a-break)

A gentle, non-intrusive companion plugin for DankMaterialShell that reminds you to rest your eyes using the 20-20-20 rule and long breaks.

## Features

- **Short & Long Breaks:** Configure separate intervals and durations for short eye-rests and longer physical breaks.
- **Non-intrusive:** Shows a small pre-warning toast 10 seconds before a break, allowing you to snooze or skip if you are in a flow state.
- **Smart Suppression:**
  - Automatically snoozes the break if you have a Fullscreen application running (e.g., watching a movie or gaming).
  - *(TODO)* Suppress during meetings: Automatically detects if the microphone is active and snoozes the break to avoid interrupting calls.
- **Control Center Integration:** Run purely in the background (daemon mode). Check your time, pause, or reset the timer directly from the Control Center.

## Implementation Notes

- **Why is Microphone detection a TODO?**
  Currently, DMS's `AudioService` (via PipeWire) provides volume and mute states but does not directly expose an `isActive` or `hasClient` state for input nodes in the QML API. Implementing this requires either an upstream update to `AudioService` or a custom script/binary to query `pw-cli` or `wpctl` periodically. For now, users can use the "Pause" button in the Control Center if they are entering a long meeting.

## Setup

Enable this plugin in the DankMaterialShell settings. You do not need to add it to your bar; it will run in the background and appear in your Control Center automatically.