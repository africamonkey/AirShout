import Testing
@testable import AirShout

struct DevicePreferencesTests {

    @Test func testDevicePreferencesSaveAndLoad() {
        let testUID = "test-device-uid-123"
        UserPreferences.shared.save(deviceUID: testUID)
        let loadedUID = UserPreferences.shared.loadDeviceUID()
        #expect(loadedUID == testUID)
        UserPreferences.shared.clear()
    }

    @Test func testDevicePreferencesClear() {
        UserPreferences.shared.save(deviceUID: "some-uid")
        UserPreferences.shared.clear()
        let loadedUID = UserPreferences.shared.loadDeviceUID()
        #expect(loadedUID == nil)
    }

    @Test func testDevicePreferencesLoadWhenEmpty() {
        UserPreferences.shared.clear()
        let loadedUID = UserPreferences.shared.loadDeviceUID()
        #expect(loadedUID == nil)
    }
}
