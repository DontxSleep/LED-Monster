# Validation

## Release 0.15.1

LED MØNSTER 0.15.1 build 25 was validated on Apple Silicon with macOS 13 as its deployment target.

### Automated checks

- App source compiled as a native `arm64-apple-macos13.0` executable.
- Scene persistence and JSON validation passed.
- Documented Bluetooth packet fixtures, RGB scaling, GATT/name gates, write ordering, coalescing, power-off priority, and disconnect queue clearing passed.
- Live brightness writes passed without waiting for slider release.
- MIDI note-on/note-off mapping, gradient midpoints, running status, disabled input, virtual output, and loop suppression passed.
- All five VFX patterns, four-colour selection, tap tempo, no-repeat random selection, BLE-paced fades, and stale-callback cancellation passed.
- All six Mood presets, paced interpolation, live brightness, running preset changes, and stale-callback cancellation passed.

### Native interface checks

- The main Monster view fits a 700 × 700 window with rounded and feathered edges.
- Mouse, QWERTY, and MIDI pad input use the same momentary state.
- The eye uses the exact active pad colour and returns to blue on release.
- The mouth remains fixed with no bite animation or colour overlay.
- Programme mode order is LED MØNSTER, LED MØNSTER VFX, Mood mode, Colour studio, and Connection details.
- Mood mode displays all six presets and Drift, Glow, and Flow timing without horizontal clipping.

### Package checks

- The installed app and release archives report version 0.15.1 build 25.
- Strict ad-hoc code-signature verification passed.
- ZIP integrity passed.
- DMG checksum, mount, app signature, executable, readme, and Applications shortcut checks passed.
- The release executable matched the installed executable by SHA-256.

Physical LED output depends on a compatible controller and cannot be read back by the app. The app only enables control writes for the documented `BJ_LED_M` / `EEA0` / `EE01` profile.

