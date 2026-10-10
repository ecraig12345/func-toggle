// Reads and toggles the live function-key mode through IOKit's IOHIDSystem service.
// Writes HIDFKeyMode and reads it back to verify the change, without editing stored
// preferences or automating System Settings. Unsupported states and service failures throw.

import Foundation
import IOKit
import IOKit.hidsystem

// Raw values match macOS's HIDFKeyMode parameter.
public enum FunctionKeyMode: Int, CaseIterable, Sendable {
    case media = 0
    case standard = 1

    public var toggled: Self {
        self == .media ? .standard : .media
    }

    public var title: String {
        switch self {
        case .media: "Media keys"
        case .standard: "Standard F1-F12"
        }
    }

    public var indicator: String {
        switch self {
        case .media: "fn: Media"
        case .standard: "fn: F"
        }
    }

    public var symbolName: String {
        switch self {
        case .media: "sun.max"
        case .standard: "f.square.fill"
        }
    }
}

public enum FunctionKeyError: LocalizedError {
    case serviceUnavailable
    case cannotReadMode
    case unsupportedMode(Int)
    case operationFailed(String, kern_return_t)
    case verificationFailed(expected: FunctionKeyMode, actual: FunctionKeyMode)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "The macOS keyboard service is unavailable."
        case .cannotReadMode:
            "macOS did not expose the current function-key mode."
        case .unsupportedMode(let value):
            "macOS reported an unsupported function-key mode (\(value))."
        case .operationFailed(let operation, let code):
            "\(operation) failed with macOS error code \(code)."
        case .verificationFailed(let expected, let actual):
            "Requested \(expected.title), but macOS still reports \(actual.title)."
        }
    }
}

public enum FunctionKeys {
    public static func currentMode() throws -> FunctionKeyMode {
        try withService { service in
            // Read live keyboard state, not the stored System Settings preference.
            guard
                let property = IORegistryEntryCreateCFProperty(
                    service, "HIDParameters" as CFString, kCFAllocatorDefault, 0
                ),
                let parameters = property.takeRetainedValue() as? [String: Any],
                let rawMode = parameters[kIOHIDFKeyModeKey] as? Int
            else {
                throw FunctionKeyError.cannotReadMode
            }
            guard let mode = FunctionKeyMode(rawValue: rawMode) else {
                throw FunctionKeyError.unsupportedMode(rawMode)
            }
            return mode
        }
    }

    @discardableResult
    public static func toggle() throws -> FunctionKeyMode {
        let desired = try currentMode().toggled
        try withService { service in
            // Parameter writes require a user-client connection, separate from the service handle.
            var connection: io_connect_t = 0
            let openResult = IOServiceOpen(
                service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection
            )
            guard openResult == KERN_SUCCESS else {
                throw FunctionKeyError.operationFailed("Opening the keyboard service", openResult)
            }
            defer { IOServiceClose(connection) }

            let value = NSNumber(value: desired.rawValue)
            let setResult = IOHIDSetCFTypeParameter(
                connection, kIOHIDFKeyModeKey as CFString, value
            )
            guard setResult == KERN_SUCCESS else {
                throw FunctionKeyError.operationFailed("Changing function-key mode", setResult)
            }
        }

        // A successful write alone does not prove that macOS applied the requested mode.
        let actual = try currentMode()
        guard actual == desired else {
            throw FunctionKeyError.verificationFailed(expected: desired, actual: actual)
        }
        return actual
    }

    private static func withService<T>(_ body: (io_service_t) throws -> T) throws -> T {
        // Keep ownership scoped so reads and writes release the service even on failure.
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass)
        )
        guard service != IO_OBJECT_NULL else {
            throw FunctionKeyError.serviceUnavailable
        }
        defer { IOObjectRelease(service) }
        return try body(service)
    }
}
