import Testing
@testable import AirShout

struct AudioManagerTests {

    @Test func testInitialState() {
        let manager = AudioManager.shared
        #expect(manager.audioLevel == 0)
        #expect(manager.isRunning == false)
    }

    @Test func testAudioLevelUpdate() {
        let manager = AudioManager.shared
        manager.audioLevel = 0.5
        #expect(manager.audioLevel == 0.5)
    }

    @Test func testStopResetsAudioLevel() {
        let manager = AudioManager.shared
        manager.audioLevel = 0.8
        manager.stop()
        #expect(manager.audioLevel == 0)
    }

    @Test func testStopSetsIsRunningToFalse() {
        let manager = AudioManager.shared
        manager.stop()
        #expect(manager.isRunning == false)
    }

    @Test func testMicrophonePermissionDeniedError() {
        let error = AudioManager.AudioError.microphonePermissionDenied
        #expect(error != nil)
    }

    @Test func testDevicePreferencesSaveAndLoad() {
        let testUID = "test-device-uid-123"
        DevicePreferences.save(deviceUID: testUID)
        let loadedUID = DevicePreferences.load()
        #expect(loadedUID == testUID)
        DevicePreferences.clear()
    }

    @Test func testDevicePreferencesClear() {
        DevicePreferences.save(deviceUID: "some-uid")
        DevicePreferences.clear()
        let loadedUID = DevicePreferences.load()
        #expect(loadedUID == nil)
    }

    @Test func testDevicePreferencesLoadWhenEmpty() {
        DevicePreferences.clear()
        let loadedUID = DevicePreferences.load()
        #expect(loadedUID == nil)
    }

    @Test func testP2PAudioManagerInitialState() {
        let manager = P2PAudioManager.shared
        #expect(manager.audioLevel == 0)
        #expect(manager.isRunning == false)
    }

    @Test func testP2PAudioManagerInitialPeersIsEmpty() {
        let manager = P2PAudioManager.shared
        #expect(manager.peers.isEmpty == true)
    }

    @Test func testP2PAudioErrorMicrophonePermissionDenied() {
        let error = P2PAudioManager.P2PError.microphonePermissionDenied
        #expect(error.errorDescription == "麦克风权限被拒绝")
    }

    @Test func testP2PAudioErrorNotConnected() {
        let error = P2PAudioManager.P2PError.notConnected
        #expect(error.errorDescription == "没有连接到任何设备")
    }

    @Test func testP2PConnectionStatusIsTransmitting() {
        #expect(P2PAudioManager.P2PConnectionStatus.speaking.isTransmitting == true)
        #expect(P2PAudioManager.P2PConnectionStatus.connected.isTransmitting == false)
        #expect(P2PAudioManager.P2PConnectionStatus.disconnected.isTransmitting == false)
    }
}
