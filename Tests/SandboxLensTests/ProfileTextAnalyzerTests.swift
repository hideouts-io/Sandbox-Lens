import XCTest
@testable import SandboxLens

final class ProfileTextAnalyzerTests: XCTestCase {
    func testExtractsBroadRulesAndImportsFromRealSBPLText() throws {
        let text = """
        (version 1)
        (deny default)
        (import "system.sb")
        (allow file-read*)
        (allow network*)
        (allow process-exec (with no-sandbox))
        """

        let analysis = try ProfileTextAnalyzer.analyze(
            data: Data(text.utf8),
            sourcePath: "/test/profile.sb"
        )

        XCTAssertTrue(analysis.hasDenyDefault)
        XCTAssertTrue(analysis.hasGlobalFileRead)
        XCTAssertTrue(analysis.hasGlobalNetwork)
        XCTAssertFalse(analysis.hasGlobalFileWrite)
        XCTAssertFalse(analysis.hasGlobalProcessExec)
        XCTAssertTrue(analysis.hasNoSandboxExecution)
        XCTAssertEqual(analysis.imports, ["system.sb"])
        XCTAssertEqual(analysis.allowCount, 3)
        XCTAssertEqual(analysis.denyCount, 1)
    }

    func testRejectsNonUTF8Data() throws {
        XCTAssertThrowsError(
            try ProfileTextAnalyzer.analyze(
                data: Data([0xC3, 0x28]),
                sourcePath: "/test/invalid.sb"
            )
        )
    }

    func testIgnoresRulesAndImportsInsideLineComments() throws {
        let text = """
        ; (allow default)
        ; (allow network*)
        ; (import "ignored.sb")
        (deny default) ; (allow file-write*)
        (import "real.sb")
        """

        let analysis = try ProfileTextAnalyzer.analyze(
            data: Data(text.utf8),
            sourcePath: "/test/comments.sb"
        )

        XCTAssertEqual(analysis.allowCount, 0)
        XCTAssertEqual(analysis.denyCount, 1)
        XCTAssertEqual(analysis.imports, ["real.sb"])
        XCTAssertFalse(analysis.hasAllowDefault)
        XCTAssertFalse(analysis.hasGlobalNetwork)
        XCTAssertFalse(analysis.hasGlobalFileWrite)
    }

    func testPreservesSemicolonsInsideQuotedStrings() throws {
        let text = #"(import "folder;name.sb")"#

        let analysis = try ProfileTextAnalyzer.analyze(
            data: Data(text.utf8),
            sourcePath: "/test/quoted-semicolon.sb"
        )

        XCTAssertEqual(analysis.imports, ["folder;name.sb"])
    }

    func testHandlesUnicodeWhitespaceAndNestedFilteredRules() throws {
        let text = """
        ; Unicode comment: café 🔒
        (deny\tdefault)
        (allow
          file-read*
          (require-all
            (subpath "/tmp/例")
            (regex #".*\\.txt$")))
        (allow unknown-operation (literal "/tmp/value"))
        """

        let analysis = try ProfileTextAnalyzer.analyze(
            data: Data(text.utf8),
            sourcePath: "/test/unicode.sb"
        )

        XCTAssertTrue(analysis.hasDenyDefault)
        XCTAssertEqual(analysis.allowCount, 2)
        XCTAssertEqual(analysis.denyCount, 1)
        XCTAssertFalse(analysis.hasGlobalFileRead)
    }

    func testEmptyAndMalformedTextRemainNonSemanticEvidence() throws {
        let emptyAnalysis = try ProfileTextAnalyzer.analyze(
            data: Data(),
            sourcePath: "/test/empty.sb"
        )
        let malformedAnalysis = try ProfileTextAnalyzer.analyze(
            data: Data("(allow network*".utf8),
            sourcePath: "/test/malformed.sb"
        )

        XCTAssertEqual(emptyAnalysis.allowCount, 0)
        XCTAssertFalse(emptyAnalysis.hasGlobalNetwork)
        XCTAssertEqual(malformedAnalysis.allowCount, 1)
        XCTAssertFalse(malformedAnalysis.hasGlobalNetwork)
    }
}
