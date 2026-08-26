import Foundation

public enum BinaryKind: String {
    case exec, dylib, framework, xpc, plugin, unknown
}

public struct MachOMagic {
    public init() {}
    public func isMachO(_ url: URL) -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            guard let data = try handle.read(upToCount: 4), data.count == 4 else { return false }
            let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
            let mh_magic: UInt32 = 0xfeedface
            let mh_cigam: UInt32 = 0xcefaedfe
            let mh_magic_64: UInt32 = 0xfeedfacf
            let mh_cigam_64: UInt32 = 0xcffaedfe
            let fat_magic: UInt32 = 0xcafebabe
            let fat_cigam: UInt32 = 0xbebafeca
            return magic == mh_magic || magic == mh_cigam || magic == mh_magic_64 || magic == mh_cigam_64 || magic == fat_magic || magic == fat_cigam
        } catch {
            return false
        }
    }
    public func detect(at url: URL) -> BinaryKind {
        let path = url.path
        if path.hasSuffix(".dylib") { return .dylib }
        if path.contains(".framework/") { return .framework }
        if path.hasSuffix(".xpc") || path.contains(".xpc/") { return .xpc }
        if path.hasSuffix(".bundle") || path.contains(".bundle/") { return .plugin }
        return .exec
    }

    public func detectArchitectures(at url: URL) -> [String] {
        architectureDetection(at: url).architectures
    }

    func architectureDetection(at url: URL) -> (architectures: [String], error: String?) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ([], "Unable to read Mach-O header")
        }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4104) else {
            return ([], "Unable to read Mach-O header")
        }
        return architectureDetection(in: data)
    }

    func detectArchitectures(in data: Data) -> [String] {
        architectureDetection(in: data).architectures
    }

    private func architectureDetection(in data: Data) -> (architectures: [String], error: String?) {
        let mhMagic: UInt32 = 0xfeedface
        let mhCigam: UInt32 = 0xcefaedfe
        let mhMagic64: UInt32 = 0xfeedfacf
        let mhCigam64: UInt32 = 0xcffaedfe
        let fatMagic: UInt32 = 0xcafebabe
        let fatCigam: UInt32 = 0xbebafeca

        func readU32LE(_ offset: Int) -> UInt32? {
            guard offset >= 0, offset <= data.count - 4 else { return nil }
            return UInt32(data[offset])
                | UInt32(data[offset + 1]) << 8
                | UInt32(data[offset + 2]) << 16
                | UInt32(data[offset + 3]) << 24
        }

        func readU32BE(_ offset: Int) -> UInt32? {
            readU32LE(offset)?.byteSwapped
        }

        func mapCPUType(_ cputype: UInt32, _ cpusubtype: UInt32) -> String? {
            let cpuTypeX8664: UInt32 = 0x01000007
            let cpuTypeArm64: UInt32 = 0x0100000c
            let cpuSubtypeMask: UInt32 = 0xff000000
            let cpuSubtypeArm64e: UInt32 = 2
            switch cputype {
            case cpuTypeX8664:
                return "x86_64"
            case cpuTypeArm64:
                return cpusubtype & ~cpuSubtypeMask == cpuSubtypeArm64e ? "arm64e" : "arm64"
            default:
                return nil
            }
        }

        guard let magic = readU32LE(0) else {
            return ([], "Truncated Mach-O header")
        }
        if magic == fatMagic || magic == fatCigam {
            let read = magic == fatCigam ? readU32BE : readU32LE
            guard let countValue = read(4), countValue <= 204 else {
                return ([], "Malformed fat Mach-O header")
            }
            let count = Int(countValue)
            guard count <= (data.count - 8) / 20 else {
                return ([], "Truncated fat Mach-O header")
            }
            var architectures: [String] = []
            for index in 0..<count {
                let offset = 8 + index * 20
                guard let cputype = read(offset), let cpusubtype = read(offset + 4) else {
                    return ([], "Truncated fat Mach-O header")
                }
                if let name = mapCPUType(cputype, cpusubtype), !architectures.contains(name) {
                    architectures.append(name)
                }
            }
            return (architectures, nil)
        }

        let read: (Int) -> UInt32?
        if magic == mhMagic || magic == mhMagic64 {
            read = readU32LE
        } else if magic == mhCigam || magic == mhCigam64 {
            read = readU32BE
        } else {
            return ([], nil)
        }
        guard let cputype = read(4), let cpusubtype = read(8),
              let name = mapCPUType(cputype, cpusubtype) else {
            if read(4) == nil || read(8) == nil {
                return ([], "Truncated Mach-O header")
            }
            return ([], nil)
        }
        return ([name], nil)
    }
}


