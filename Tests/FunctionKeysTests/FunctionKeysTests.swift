import AppKit
import FunctionKeys
import Testing

@Test func modesMatchHIDValues() {
    #expect(FunctionKeyMode(rawValue: 0) == .media)
    #expect(FunctionKeyMode(rawValue: 1) == .standard)
    #expect(FunctionKeyMode(rawValue: 2) == nil)
}

@Test(arguments: FunctionKeyMode.allCases)
func togglingChangesModeAndIsReversible(mode: FunctionKeyMode) {
    #expect(mode.toggled != mode)
    #expect(mode.toggled.toggled == mode)
    #expect(!mode.title.isEmpty)
    #expect(!mode.indicator.isEmpty)
}

@Test func errorsExplainFailures() {
    let errors: [FunctionKeyError] = [
        .serviceUnavailable,
        .cannotReadMode,
        .unsupportedMode(42),
        .operationFailed("Changing mode", -1),
        .verificationFailed(expected: .standard, actual: .media)
    ]
    for error in errors {
        #expect(!(error.errorDescription ?? "").isEmpty)
    }
    #expect(FunctionKeyError.unsupportedMode(42).errorDescription?.contains("42") == true)
}

@Test @MainActor func statusSymbolsMatchModesAndAreAvailable() {
    #expect(FunctionKeyMode.standard.symbolName == "f.square.fill")
    #expect(FunctionKeyMode.media.symbolName == "sun.max")
    for mode in FunctionKeyMode.allCases {
        #expect(NSImage(systemSymbolName: mode.symbolName, accessibilityDescription: mode.title) != nil)
    }
}
