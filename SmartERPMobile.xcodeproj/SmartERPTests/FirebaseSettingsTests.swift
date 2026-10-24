import Testing
@testable import SmartERPMobile

@Suite("Firebase settings")
struct FirebaseSettingsTests {
    @Test(
        "Configuration validation accepts only nonempty lowercase project identifiers",
        arguments: [
            ("smart-erp-123", "api-key", true),
            ("project1", "api-key", true),
            ("", "api-key", false),
            ("smart-erp", "", false),
            ("Smart-ERP", "api-key", false),
            ("smart_erp", "api-key", false),
            ("smart erp", "api-key", false)
        ]
    )
    func validation(projectID: String, apiKey: String, expected: Bool) {
        let settings = FirebaseSettings(projectID: projectID, apiKey: apiKey)
        #expect(settings.isValid == expected)
    }

    @Test("Backup errors provide actionable messages")
    func errorDescriptions() {
        #expect(FirebaseBackupError.configuration.errorDescription == "Enter a Firebase project ID and Web API key.")
        #expect(FirebaseBackupError.response.errorDescription == "Firebase returned an unexpected response.")
        #expect(FirebaseBackupError.noBackup.errorDescription == "No cloud backup exists for this Google account.")
        #expect(FirebaseBackupError.server("Permission denied").errorDescription == "Permission denied")
    }
}
