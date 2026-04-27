import XCTest
@testable import TetherKitLoader

final class TetherKitDriverTests: XCTestCase {
    func testDriverStateBadgeLabelsMatchUIStates() {
        XCTAssertEqual(DriverState.unknown.badgeLabel, "Unknown")
        XCTAssertEqual(DriverState.notInstalled.badgeLabel, "Not installed")
        XCTAssertEqual(DriverState.waitingForApproval.badgeLabel, "Needs approval")
        XCTAssertEqual(DriverState.installed.badgeLabel, "Active")
        XCTAssertEqual(DriverState.pendingInstallAfterReboot.badgeLabel, "Reboot to finish install")
        XCTAssertEqual(DriverState.pendingUninstallAfterReboot.badgeLabel, "Reboot to finish removal")
    }

    func testDriverStateSummariesRemainActionable() {
        XCTAssertTrue(DriverState.unknown.summary.contains("unknown"))
        XCTAssertTrue(DriverState.waitingForApproval.summary.contains("System Settings"))
        XCTAssertTrue(DriverState.pendingInstallAfterReboot.summary.contains("reboot"))
        XCTAssertTrue(DriverState.installed.summary.contains("installed and active"))
    }
}
