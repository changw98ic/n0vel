import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testWindowSizingMatchesDesignBaseline() {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let windowSource = try? String(
      contentsOf: repoRoot.appendingPathComponent("Runner/MainFlutterWindow.swift"),
      encoding: .utf8
    )
    let mainMenuSource = try? String(
      contentsOf: repoRoot.appendingPathComponent("Runner/Base.lproj/MainMenu.xib"),
      encoding: .utf8
    )

    XCTAssertNotNil(windowSource)
    XCTAssertNotNil(mainMenuSource)
    XCTAssertTrue(windowSource?.contains("1440") == true)
    XCTAssertTrue(windowSource?.contains("1024") == true)
    XCTAssertTrue(windowSource?.contains("1280") == true)
    XCTAssertTrue(windowSource?.contains("960") == true)
    XCTAssertTrue(mainMenuSource?.contains("width=\"1440\"") == true)
    XCTAssertTrue(mainMenuSource?.contains("height=\"1024\"") == true)
  }

}
