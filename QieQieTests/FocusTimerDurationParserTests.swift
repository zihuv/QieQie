import XCTest
@testable import QieQie

final class FocusTimerDurationParserTests: XCTestCase {
    func testParseAcceptsPositiveMinutesAndSeconds() {
        XCTAssertEqual(FocusTimerDurationParser.parse(minutes: "25", seconds: "30"), 1530)
    }

    func testParseRejectsZeroDuration() {
        XCTAssertNil(FocusTimerDurationParser.parse(minutes: "0", seconds: "0"))
    }

    func testParseRejectsInvalidSeconds() {
        XCTAssertNil(FocusTimerDurationParser.parse(minutes: "10", seconds: "60"))
        XCTAssertNil(FocusTimerDurationParser.parse(minutes: "10", seconds: "-1"))
    }

    func testParseRejectsNonNumericInput() {
        XCTAssertNil(FocusTimerDurationParser.parse(minutes: "ab", seconds: "10"))
        XCTAssertNil(FocusTimerDurationParser.parse(minutes: "10", seconds: "xy"))
    }

    func testSanitizeNumericInputFiltersAndCapsUpperBound() {
        XCTAssertEqual(
            FocusTimerDurationParser.sanitizeNumericInput("a9b7", maxLength: 2, upperBound: 59),
            "59"
        )
        XCTAssertEqual(
            FocusTimerDurationParser.sanitizeNumericInput("1234", maxLength: 3),
            "123"
        )
    }
}
