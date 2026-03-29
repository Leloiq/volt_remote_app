# Architecture Analysis: Android TV Pairing & Control

This document analyzes the current state of Android TV support within the Volt Remote App and proposes an implementation plan to support native, secure pairing and remote control for actual Android TV devices.

## Current State Analysis

1.  **Discovery (`discovery_service.dart`)**:
    *   The app currently uses mDNS (Bonjour/ZeroConf) to scan for `_androidtvremote2._tcp.local` and marks discovered devices as `TvBrand.androidTv` on port 6466. 
    *   *Conclusion:* Discovery is working correctly for modern Android TVs.

2.  **Pairing (`pairing_service.dart`)**:
    *   Currently, the pairing service is structured entirely around a simulated HTTP endpoint (`http://<ip>:8080/pair`) which takes a 6-digit code and returns a Bearer Token.
    *   *Conclusion:* This works for the "VOLT TV Simulator", but native Android TVs **do not** expose a simple HTTP pairing server. Android TVs use a custom TLS-encrypted pairing protocol.

3.  **Command Execution (`android_tv_controller.dart`)**:
    *   The `AndroidTVController` class has placeholders indicating an intention to use ADB (Android Debug Bridge) via port 5555 (`// ADB: am start -n $appId`).
    *   *Conclusion:* ADB requires the user to manually enable Developer Options and Wireless Debugging on their TV, which is an extremely poor experience for a consumer application.

---

## Proposed Implementation Plan

To properly remote control a real Android TV without requiring Developer Options, we must use the **official Android TV Remote Service Protocol (v2)**.

### Phase 1: TLS Certificate Management
The official protocol requires mutual TLS authentication.
*   **Generate Client Certificates:** We need to generate a self-signed RSA certificate on the mobile device when the app installs.
*   **Store Certificates:** Store the generated public/private keys securely using `flutter_secure_storage`.

### Phase 2: Implement the Pairing Protocol (Port 6467)
Android TV Remote Protocol uses encrypted Protobuf messages.
1.  **Dependencies:** Add `protobuf` and cryptography packages to `pubspec.yaml` to handle binary protocol buffers.
2.  **Pairing Handshake:**
    *   Connect to the TV on port 6467.
    *   Exchange certificates.
    *   The TV will display a 6-digit PIN on the screen.
    *   Prompt the user in the app to enter this PIN.
    *   Send the cryptographic hash containing the PIN and certificates back to the TV.
    *   Upon success, save the TV's certificate so future connections don't require a PIN.

### Phase 3: Implement the Control Protocol (Port 6466)
Once paired, the connection shifts to the Remote Control service.
1.  **Message Routing:** Update `AndroidTVController` to connect to port 6466 using the paired TLS certificates.
2.  **Protobuf KeyEvents:** Translate our `RemoteCommand` enums into the Android TV Protobuf `KeyEvent` messages (e.g., `KEYCODE_DPAD_UP`).
3.  **App Launching:** Implement the `LaunchAppLink` protobuf message to deep-link users into Netflix, YouTube, etc.

---

## Alternative (Faster but Less Native)

If you prefer to stick to your existing HTTP/Token pairing flow, we can do one of the following:

*   **ADB over Network (Requires Developer Mode):** We can install a Dart ADB library. Users will have to go to their TV settings, click the build number 7 times, enable debugging, and allow the connection.
*   **TV-side Companion App:** We can build a small Android TV companion app (apk) that users install on their TV, which acts as the HTTP server (`:8080`) you currently have modeled in `pairing_service.dart`.

> [!IMPORTANT]
> **User Review Required**
> Do you want to implement the official, complex **Protobuf/TLS protocol** (seamless consumer experience, no TV config needed), or do you want to use the **ADB approach** (easier to code, but very hard for users to set up on their TV)? 

## Verification Plan

### Automated / Unit tests
1. Mock the Android TV Remote Service Protobuf channels and verify the handshake byte sequences.
2. Test certificate generation logic locally.

### Manual Verification
1. Attempt to pair with a physical Android TV or Android TV Emulator.
2. Verify the TV displays the 6-digit PIN code dialog.
3. Validate that D-PAD and Volume commands manipulate the TV interface in real-time.
