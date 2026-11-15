// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import AppKit

@objc(HardWrapDialogController)
final class HardWrapDialogController: NSObject {
    @IBOutlet var window: NSWindow!
    @IBOutlet var widthField: NSTextField!

    private let widthRange: ClosedRange<Int>
    private(set) var width: Int

    init(width: Int, widthRange: ClosedRange<Int>) {
        self.width = width
        self.widthRange = widthRange
    }

    @IBAction func accept(_ sender: Any?) {
        let input = widthField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(input), widthRange.contains(value) else {
            let alert = NSAlert()
            alert.messageText = "Width must be a whole number from \(widthRange.lowerBound) to \(widthRange.upperBound)."
            alert.informativeText = "Use 0 to unwrap."
            alert.runModal()
            widthField.selectText(nil)
            return
        }

        width = value
        NSApp.stopModal(withCode: .OK)
    }

    @IBAction func cancel(_ sender: Any?) {
        NSApp.stopModal(withCode: .cancel)
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let width = Int(arguments[1]),
      let minimum = Int(arguments[2]),
      let maximum = Int(arguments[3]),
      minimum <= width, width <= maximum else {
    fail("Usage: HardWrapDialog WIDTH MINIMUM MAXIMUM")
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let nibURL = URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("HardWrapDialog.nib")
guard let nibData = try? Data(contentsOf: nibURL) else {
    fail("Could not read HardWrapDialog.nib beside the helper.")
}

let nib = NSNib(nibData: nibData, bundle: nil)
let controller = HardWrapDialogController(width: width, widthRange: minimum...maximum)
var topLevelObjects: NSArray?
guard nib.instantiate(withOwner: controller, topLevelObjects: &topLevelObjects),
      let window = controller.window,
      let widthField = controller.widthField else {
    fail("Could not load HardWrapDialog.nib or connect its outlets.")
}

widthField.stringValue = String(width)
window.initialFirstResponder = widthField
application.activate(ignoringOtherApps: true)

let response = withExtendedLifetime(topLevelObjects) {
    application.runModal(for: window)
}
window.orderOut(nil)
print(response == .OK ? String(controller.width) : "cancel")
