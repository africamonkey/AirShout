import Testing
@testable import AirShout

struct AudioManagerTests {

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
