import Foundation

public enum BinaryKind: String {
    case exec, dylib, framework, xpc, plugin, unknown
}

public struct MachOMagic {
    public init() {}
    public func detect(at url: URL) -> BinaryKind {
        let path = url.path
        if path.hasSuffix(".dylib") { return .dylib }
        if path.contains(".framework/") { return .framework }
        if path.hasSuffix(".xpc") || path.contains(".xpc/") { return .xpc }
        if path.hasSuffix(".bundle") || path.contains(".bundle/") { return .plugin }
        return .exec
    }

    public func detectArchitectures(at url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return [] }
        if data.count < 8 { return [] }

        let MH_MAGIC: UInt32 = 0xfeedface
        let MH_CIGAM: UInt32 = 0xcefaedfe
        let MH_MAGIC_64: UInt32 = 0xfeedfacf
        let MH_CIGAM_64: UInt32 = 0xcffaedfe
        let FAT_MAGIC: UInt32 = 0xcafebabe
        let FAT_CIGAM: UInt32 = 0xbebafeca

        func readU32LE(_ offset: Int) -> UInt32 {
            let slice = data[offset..<(offset+4)]
            return slice.withContiguousStorageIfAvailable { buf in
                return buf.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
            } ?? UInt32(littleEndian: data[offset..<(offset+4)].withUnsafeBytes { $0.load(as: UInt32.self) })
        }
        func readU32BE(_ offset: Int) -> UInt32 {
            return readU32LE(offset).byteSwapped
        }

        func mapCPUType(_ cputype: UInt32) -> String? {
            let CPU_TYPE_X86_64: UInt32 = 0x01000007
            let CPU_TYPE_ARM64: UInt32 = 0x0100000C
            switch cputype {
            case CPU_TYPE_X86_64: return "x86_64"
            case CPU_TYPE_ARM64: return "arm64"
            default: return nil
            }
        }

        let magic = readU32LE(0)
        if magic == FAT_MAGIC || magic == FAT_CIGAM {
            let be = (magic == FAT_CIGAM)
            let nfat = be ? readU32BE(4) : readU32BE(4) // nfat_arch is big-endian in both FAT_MAGIC/CIGAM
            var archs: Set<String> = []
            var offset = 8
            for _ in 0..<Int(nfat) {
                let cputypeBE = readU32BE(offset)
                if let name = mapCPUType(cputypeBE) { archs.insert(name) }
                offset += 20 // sizeof(fat_arch)
            }
            return Array(archs)
        } else if magic == MH_MAGIC || magic == MH_MAGIC_64 {
            // little endian headers
            let cputype = readU32LE(4)
            if let name = mapCPUType(cputype) { return [name] }
        } else if magic == MH_CIGAM || magic == MH_CIGAM_64 {
            // big endian headers
            let cputype = readU32BE(4)
            if let name = mapCPUType(cputype) { return [name] }
        }
        return []
    }
}


