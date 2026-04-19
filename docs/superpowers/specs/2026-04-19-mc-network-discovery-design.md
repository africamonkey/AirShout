# AirShout MC-Enhanced Network Discovery Design

## Overview

Enhance the Network tab with MultipeerConnectivity (MC) to automatically discover devices on the local network and exchange IP/port information. Users can then connect via TCP for audio streaming.

## Goals

- MC discovers devices and exchanges `{ip, port, deviceName}`
- Discovered devices appear in "Saved Connections" with `source = .discovered`
- User manually selects a device and connects via TCP
- Device name configurable in Settings (defaults to `UIDevice.current.name`)
- Deduplicate by `ip + port`

## Architecture

### Components

| Component | Responsibility |
|-----------|----------------|
| `MultipeerManager` | MC Browser/Session management, info exchange |
| `NetworkManager` | Existing TCP Server/Client for audio streaming |
| `SavedConnectionStorage` | Existing persistence layer |
| `SettingsView` | Device name configuration |

### Data Model

```swift
enum ConnectionSource: String, Codable {
    case manual      // User manually added
    case discovered  // MC discovered
    case connected   // Previously connected via TCP
}

struct SavedConnection: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var ip: String
    var port: UInt16
    var source: ConnectionSource
    var lastConnected: Date?

    // Deduplication key: ip + port
}
```

## Behavior

### App Launch Sequence

1. **MC Session Start**: Start MC Browser and Advertiser on app launch
2. **IP Detection**: Detect local IP address
3. **Port Restoration**: Restore last used port from SavedConnection (or use system-assigned port)
4. **TCP Listener**: Start TCP Listener on the port
5. **MC Broadcast**: Advertise local `{ip, port, deviceName}` to all MC peers

### MC Discovery Flow

```
1. MC finds peer → invitation → accept
2. Exchange local info via MC session:
   Local → Peer: { ip, port, deviceName }
   Peer → Local: { ip, port, deviceName }
3. On receiving peer info:
   - Check if ip+port exists in savedConnections
   - If exists: update name from MC peer
   - If not: create new SavedConnection with source=.discovered
```

### IP/Port Change Handling

When local IP or port changes:
1. Detect change (via NWListener delegate or periodic check)
2. Update local IP/Port
3. Re-advertise via MC session to all connected peers
4. Other devices update their SavedConnection entries

### Connection Deduplication

- Use `ip + port` as unique key
- When MC discovers a device already in SavedConnections:
  - If `source == .manual`: update `name` and `source = .discovered`
  - If `source == .discovered`: update `name`
  - If `source == .connected`: update `name` and `source = .connected`

## UI Changes

### LocalInfoView

- Display current device name (from Settings)
- Display current IP
- Port text field (editable, persisted)
- Start/Stop listening button

### ConnectionListView

- Show source indicator per connection:
  - 🔗 Manual
  - 📡 Discovered (MC)
  - ✅ Connected (TCP)
- Delete available for all types

### SettingsView (New)

- **Device Name**: Text field, defaults to `UIDevice.current.name`
- Persisted in UserPreferences

## Technical Details

### MC Configuration

- **Service Type**: `airshout-p2p`
- **Discovery Info**: `["deviceName": <deviceName>]`
- Run on dedicated queue: `com.airshout.multipeer`

### Info Exchange Protocol

MC session sends JSON-encoded payload:
```json
{
  "ip": "192.168.1.100",
  "port": 52341,
  "deviceName": "My iPhone"
}
```

### Port Strategy

1. Default: `port = 0` (system assigns high port)
2. Restore: Try last saved port first
3. Conflict: Fall back to system-assigned port
4. User override: Manual port in LocalInfoView

## Thread Safety

- MC callbacks on `mcQueue`
- Network operations on `networkQueue`
- UI updates on `MainActor`
- Shared state access via `connectionsQueue`

## Files to Create/Modify

### New Files
- `AirShout/Core/Network/MultipeerManager.swift`

### Modified Files
- `AirShout/Core/Models/SavedConnection.swift` - Add `source` field
- `AirShout/Shared/Preferences/UserPreferences.swift` - Add `deviceName`
- `AirShout/Views/Network/LocalInfoView.swift` - Add device name display
- `AirShout/Views/Network/ConnectionListView.swift` - Show source indicator
- `AirShout/Views/Settings/SettingsView.swift` - New Settings view
- `AirShout/Views/MainTabView.swift` - Add Settings tab
- `AirShout/Features/Network/NetworkViewModel.swift` - Integrate MC Manager
- `AirShout/AirShoutApp.swift` - Auto-start MC on launch

## Out of Scope

- P2P tab modifications (keeps existing MC-based voice chat)
- Audio streaming over MC (uses existing TCP-based NetworkManager)
