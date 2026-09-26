# LED MØNSTER

Version 0.15.1 · Mac app

Control your BJ_LED_M Bluetooth LED strip with solid and gradient pads, keyboard shortcuts, MIDI, live brightness adjustment and a new random four-colour VFX sequencer.

## Install

Requires an Apple Silicon Mac (M-series), macOS 13 or later, and Bluetooth. This build does not support Intel Macs.

1. Open **LED Monster.dmg**, or unzip **LED Monster.zip** if using the ZIP download.
2. Drag **LED MØNSTER.app** to your Applications folder. The DMG includes an Applications shortcut.
3. Open the app and allow Bluetooth access when prompted.

After copying the app from the DMG, eject the **LED Monster** disk in Finder.

This is a personal build and is not Apple-notarized; macOS may ask for approval before opening it on another Mac.

## Connect your lights

1. Power on the LED strip and close MohuanLED or any other app connected to it.
2. Open the small menu in the top-left corner of LED MØNSTER.
3. Click **Scan nearby**, find **BJ_LED_M**, then click **Connect**.
4. Close the menu, then hold a colour pad to light the strip. Release it to switch the strip off.

On the Monster page, a newly connected strip is switched off so the pads can behave momentarily. No colour is sent until you hold a pad. Without a connection, the pads only preview colours on screen. Other Bluetooth LED controllers are not supported by this build.

## Play the pads

Hold a pad or its letter while the Monster screen is active and the menu is closed. The colour stays on only while held and switches off on release.

While a pad is held, the monster's eye changes to that exact colour. Releasing the mouse, keyboard key or MIDI note returns the eye to blue. The mouth stays fixed with no animation or colour overlay.

| Key | Colour | MIDI note |
| --- | --- | --- |
| Q | Red | 60 |
| W | Green | 61 |
| E | Blue | 62 |
| R | Yellow | 63 |
| T | Cyan | 64 |
| Y | Magenta | 65 |
| A | Red→yellow gradient midpoint (orange) | 66 |
| S | Green→cyan gradient midpoint (spring green) | 67 |
| D | Blue→magenta gradient midpoint (violet) | 68 |

The old brightness knob has been replaced by the monster's open mouth, with red gums and rows of teeth. Monster pads now use full brightness. The Monster page's **On** control is disabled because pad presses control power; **Off** remains available as an emergency stop. Colour Studio and LED MØNSTER VFX retain their own brightness controls.

## Menu and window

- The top-left button or **Command-L** opens and closes **Parameters**.
- **Programme mode** switches between **LED MØNSTER**, **LED MØNSTER VFX**, **Mood mode**, **Colour studio** and **Connection details**.
- The **Monster** button returns from another mode to the full artwork.
- Drag the empty top or bottom rim to move the window. Minimise and Close app are in Parameters.
- Keyboard shortcuts and accessibility still work without the macOS pink focus box appearing over controls.

## LED MØNSTER VFX

Choose **LED MØNSTER VFX** in Programme mode. Pick exactly four colours from the 16-pad palette, choose **Colour Flash 1**, **Quick**, **Slow**, **Fade** or **Jump**, then click **Start VFX**. Effects choose randomly from your four colours and avoid an immediate repeat.

Click **Tap to BPM** repeatedly, or press the Spacebar, to measure the beat; the live BPM appears to its right. VFX brightness updates while you drag. **Stop**, **Off**, changing programme mode, opening Parameters or losing the Bluetooth connection stops the sequence safely.

## Mood mode

Choose **Mood mode** in Programme mode, select Relax, Sunset, Ocean, Forest, Focus or Midnight, then choose a transition speed and click **Start mood**. The three colours in the selected atmosphere crossfade continuously. Brightness updates while the mood is running.

**Stop**, **Off**, changing programme mode, opening Parameters or losing the Bluetooth connection stops the mood safely.

## MIDI keyboard or music software

Enable **MIDI keyboard** in Parameters, then close the menu and return to the Monster screen. Connected MIDI sources can trigger notes **60–68** on any channel. MIDI note-on lights the mapped colour and note-off, including note-on with zero velocity, switches it off. Note velocity does not change brightness.

In your music software, send MIDI to **LED MØNSTER Input**. To receive notes from clicking the pads or pressing Q/W/E/R/T/Y/A/S/D, choose **LED MØNSTER Pads** as the MIDI input. Incoming notes are not echoed back.

## If the strip does not respond

Check its power, move the Mac closer, close other controller apps, and reconnect. Check that brightness is above zero, then hold a colour pad. For diagnostics, use the macOS menu **Controller → Export report…**.

The app runs locally without an account. Saved scenes stay on your Mac. The app cannot read back the strip's actual colour or power state.
