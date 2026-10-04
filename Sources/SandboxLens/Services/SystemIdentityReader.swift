import Darwin
import Foundation

enum SystemIdentityReader {
    static func current() throws -> SystemIdentity {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let productVersion = productVersionString(version: version)
        let buildVersion = try systemBuildVersion()
        return SystemIdentity(productVersion: productVersion, buildVersion: buildVersion)
    }

    static func productVersionString(version: OperatingSystemVersion) -> String {
        let majorMinor = "\(version.majorVersion).\(version.minorVersion)"
        guard version.patchVersion != 0 else {
            return majorMinor
        }
        return "\(majorMinor).\(version.patchVersion)"
    }

    private static func systemBuildVersion() throws -> String {
        var requiredSize: size_t = 0
        guard sysctlbyname("kern.osversion", nil, &requiredSize, nil, 0) == 0 else {
            throw SystemIdentityError.sysctlFailed(errnoValue: errno)
        }

        var buffer = [CChar](repeating: 0, count: requiredSize)
        guard sysctlbyname("kern.osversion", &buffer, &requiredSize, nil, 0) == 0 else {
            throw SystemIdentityError.sysctlFailed(errnoValue: errno)
        }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

enum SystemIdentityError: LocalizedError {
    case sysctlFailed(errnoValue: Int32)

    var errorDescription: String? {
        switch self {
        case .sysctlFailed(let errnoValue):
            "The macOS build number could not be read with sysctl. errno=\(errnoValue)."
        }
    }
}
