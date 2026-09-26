# BJ_LED_M control protocol — evidence and limits

## Captured on the user's controller

`protocol-analysis/bj-led-m-observed-gatt.json` records device name `BJ_LED_M`, primary service `EEA0`, characteristic `EE01` (read, write without response, notify) and `EE02` (read, write with/without response). EE01 notification subscription fails with “The attribute could not be found.” This does not establish whether writes succeed.

## Public implementation evidence

- [8none1/bj_led, pinned implementation](https://github.com/8none1/bj_led/blob/f66853eb10ca8ce0c2ce19a6bcb5bdc5cbfcca90/custom_components/bj_led/bjled.py): uses EE01, writes without response, power `69 96 02 01 01` / `69 96 02 01 00`, RGB prefix `69 96 05 02` followed by three channels. Brightness scales RGB. Its README's `06` power-on byte conflicts with its implementation; Luma follows code corroborated by the second project.
- [Walkercito/MohuanLED-Bluetooth_LED, pinned manager](https://github.com/Walkercito/MohuanLED-Bluetooth_LED/blob/e9128dc95bb5e592cd71fdfe8e606ce4fe0b397d/bluelights/manager.py): explicitly targets BJ_LED_M and independently implements the same power packets and seven-byte RGB packet, with software brightness scaling and no-response writes. Its scanner tries characteristics; Luma does not adopt that probing behavior.
- [SidmoGoesBrrr/led-controller-app](https://github.com/SidmoGoesBrrr/led-controller-app/blob/0154fa2405f7d5850ed2286124f51672fbcb484b/src/services/BLEService.ts): uses an eighth brightness byte and chooses the first writable characteristic. This conflicts with the above implementations and was not adopted.

## Luma 0.2.0 implementation

Requires exact advertised name BJ_LED_M, service EEA0, a unique EE01 characteristic and write-without-response support. CoreBluetooth uses the discovered characteristic object; there is no guessed handle or automatic fallback to a different device/channel. Matching this fingerprint is compatibility evidence, not cryptographic device identity. The user selects the device.

| Action | Packet |
|---|---|
| On | `69 96 02 01 01` |
| Off | `69 96 02 01 00` |
| Red at 100% | `69 96 05 02 FF 00 00` |
| Green at 100% | `69 96 05 02 00 FF 00` |
| Blue at 100% | `69 96 05 02 00 00 FF` |
| White at 50% | `69 96 05 02 7F 7F 7F` |

Each channel is floor(normalized channel × 255 × normalized brightness). There is no checksum, optional eighth byte, handshake, or notification prerequisite in these adopted encoders. The app does not implement vendor effects, music, timers, reset, firmware or pairing commands.

Only explicit user actions send commands. Connecting does not change the strip. Choosing a scene, releasing a slider or pressing Apply sends colour; the first colour action also queues power-on. On and Off send only their power command. Commands are spaced at least 120ms apart and honor CoreBluetooth backpressure. Unsent colour updates are coalesced. Off cancels pending commands. Disconnect/Bluetooth loss clears work; nothing is replayed on reconnection.

Without-response transport provides no device acknowledgement. “Sent” means handed to CoreBluetooth, not that physical LEDs were observed to change. Requested state is kept separate from telemetry; the UI and JSON report do not claim hardware verification. Physical verification is still required for this specific controller revision.
