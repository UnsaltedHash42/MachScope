import Foundation
import Testing

@Suite(.serialized) struct CLITests {
    @Test func quickConsumesFlagsAndProducesJSON() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI(["quick", fixture.binary.path, "--format", "json"])
        let object = try jsonObject(result.stdout)

        #expect(result.status == 0)
        #expect(object["schema_version"] as? Int == 1)
    }

    @Test func unknownFlagExitsTwo() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI(["scan", fixture.binary.path, "--bogus-flag"])

        #expect(result.status == 2)
        #expect(result.stderr.contains("--bogus-flag"))
    }

    @Test func failOnThresholdControlsExitCode() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let highRules = fixture.root.appendingPathComponent("high.yml")
        let lowRules = fixture.root.appendingPathComponent("low.yml")
        try rules(severity: "high").write(to: highRules, atomically: true, encoding: .utf8)
        try rules(severity: "low").write(to: lowRules, atomically: true, encoding: .utf8)

        let high = try runCLI([
            "scan", fixture.binary.path,
            "--rules", highRules.path,
            "--fail-on", "high"
        ])
        let low = try runCLI([
            "scan", fixture.binary.path,
            "--rules", lowRules.path,
            "--fail-on", "high"
        ])
        let defaultExit = try runCLI([
            "scan", fixture.binary.path,
            "--rules", highRules.path
        ])

        #expect(high.status == 1)
        #expect(low.status == 0)
        #expect(defaultExit.status == 0)
    }

    @Test func nonexistentRootExitsThree() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path

        let result = try runCLI(["scan", path])

        #expect(result.status == 3)
    }

    @Test func quickAndScanMatchWithEquivalentOptions() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let quick = try runCLI([
            "quick", fixture.root.path,
            "--format", "json",
            "--concurrency", "2"
        ])
        let scan = try runCLI([
            "scan", fixture.root.path,
            "--format", "json",
            "--exclude", "/System,/Library",
            "--max-depth", "8",
            "--concurrency", "2"
        ])

        #expect(quick.status == 0)
        #expect(scan.status == 0)
        #expect(try recordsData(quick.stdout) == recordsData(scan.stdout))
    }

    @Test func helpAndBareInvocationUseContractExitCodes() throws {
        let help = try runCLI(["--help"])
        let bare = try runCLI([])

        #expect(help.status == 0)
        #expect(String(decoding: help.stdout, as: UTF8.self).contains("Usage:"))
        #expect(bare.status == 2)
        #expect(bare.stderr.contains("Usage:"))
    }

    private func runCLI(_ arguments: [String]) throws -> Result {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = packageRoot()
            .appendingPathComponent(".build/debug/machscope")
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        return Result(
            status: process.terminationStatus,
            stdout: stdout.fileHandleForReading.readDataToEndOfFile(),
            stderr: String(
                decoding: stderr.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
        )
    }

    private func makeFixture() throws -> (root: URL, binary: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let binary = root.appendingPathComponent("fixture")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/bin/ls"),
            to: binary
        )
        return (root, binary)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func recordsData(_ data: Data) throws -> Data {
        let object = try jsonObject(data)
        let records = try #require(object["records"] as? [[String: Any]])
        return try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
    }

    private func rules(severity: String) -> String {
        """
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: TEST_FINDING
            severity: \(severity)
            reason: Test finding
            all:
              - flag: absent-test-flag
                present: false
        """
    }

    private struct Result {
        let status: Int32
        let stdout: Data
        let stderr: String
    }
}
