import Foundation
import Testing
@testable import MachScopeCore

@Suite struct ScannerTests {
    @Test func excludesWholeComponentsWithoutMatchingSubstrings() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let frameworks = root.appendingPathComponent("Frameworks")
        let helper = root.appendingPathComponent("FrameworksHelper")
        try FileManager.default.createDirectory(at: frameworks, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helper, withIntermediateDirectories: true)
        try machoHeader().write(to: frameworks.appendingPathComponent("excluded"))
        let included = helper.appendingPathComponent("included")
        try machoHeader().write(to: included)

        let paths = FileWalker().enumeratePaths(options: .init(
            root: root,
            excludes: ["Frameworks"]
        ))

        #expect(paths.map(\.lastPathComponent) == [included.lastPathComponent])
    }

    @Test func symlinksAreAlwaysSkipped() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target")
        let link = root.appendingPathComponent("link")
        try machoHeader().write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let paths = FileWalker().enumeratePaths(options: .init(root: root))

        #expect(paths.map(\.lastPathComponent) == [target.lastPathComponent])
    }

    @Test func badFilesDoNotAbortBatchScan() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let valid = root.appendingPathComponent("valid")
        let truncated = root.appendingPathComponent("truncated")
        let unreadable = root.appendingPathComponent("unreadable")
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/bin/ls"),
            to: valid
        )
        try Data([0xcf, 0xfa, 0xed, 0xfe]).write(to: truncated)
        try machoHeader().write(to: unreadable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0],
            ofItemAtPath: unreadable.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: unreadable.path
            )
        }

        let records = Scanner().scan(
            urls: [valid, truncated, unreadable],
            concurrency: 3
        )

        #expect(records.count == 3)
        #expect(Set(records.map(\.path)) == Set([valid.path, truncated.path, unreadable.path]))
        #expect(records.first { $0.path == truncated.path }?.errors.isEmpty == false)
        #expect(records.first { $0.path == unreadable.path }?.errors.isEmpty == false)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func machoHeader() -> Data {
        Data([
            0xcf, 0xfa, 0xed, 0xfe,
            0x0c, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00
        ])
    }
}
