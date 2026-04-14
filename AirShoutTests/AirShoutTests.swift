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
}
