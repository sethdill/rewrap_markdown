// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import AppKit

enum ListIndentation: String, CaseIterable {
    case preserve, spaces, tabs

    var menuTag: Int { Self.allCases.firstIndex(of: self)! }
}

struct WrapOptions {
    var width: Int
    var unwrap: Bool = false
    var repair: Bool = false
    var indentation: ListIndentation = .preserve

    var result: String {
        [String(width), unwrap ? "1" : "0", repair ? "1" : "0", indentation.rawValue].joined(separator: "\t")
    }
}

final class WidthFormatter: NumberFormatter, @unchecked Sendable {
    override func isPartialStringValid(
        _ partialString: String,
        newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        partialString.utf8.allSatisfy { (48...57).contains($0) }
    }
}

@objc(HardWrapDialogController)
final class HardWrapDialogController: NSObject {
    @IBOutlet var window: NSWindow!
    @IBOutlet var widthField: NSTextField!
    @IBOutlet var unwrapButton: NSButton!
    @IBOutlet var repairButton: NSButton!
    @IBOutlet var indentationMenu: NSPopUpButton!
    @IBOutlet var versionLabel: NSTextField!

    private let widthRange: ClosedRange<Int>
    private(set) var options: WrapOptions

    init(options: WrapOptions, widthRange: ClosedRange<Int>) {
        self.options = options
        self.widthRange = widthRange
    }

    func configure(formatterVersion: String) {
        let formatter = WidthFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.allowsFloats = false
        formatter.usesGroupingSeparator = false
        formatter.isPartialStringValidationEnabled = true
        widthField.formatter = formatter
        widthField.integerValue = options.width
        widthField.isEnabled = !options.unwrap
        unwrapButton.state = options.unwrap ? .on : .off
        repairButton.state = options.repair ? .on : .off
        indentationMenu.selectItem(withTag: options.indentation.menuTag)
        versionLabel.stringValue = formatterVersion
        window.initialFirstResponder = options.unwrap ? unwrapButton : widthField
        window.autorecalculatesKeyViewLoop = true
    }

    private var enteredWidth: Int? {
        let text = widthField.currentEditor()?.string ?? widthField.stringValue
        guard let value = Int(text), widthRange.contains(value) else { return nil }
        return value
    }

    @IBAction func toggleUnwrap(_ sender: Any?) {
        if unwrapButton.state == .on {
            if let value = enteredWidth, value > 0 {
                options.width = value
            }
            widthField.abortEditing()
            widthField.integerValue = options.width
            widthField.isEnabled = false
        } else {
            widthField.isEnabled = true
            widthField.selectText(nil)
        }
    }

    @IBAction func accept(_ sender: Any?) {
        let unwrap = unwrapButton.state == .on
        let value = unwrap ? options.width : enteredWidth
        guard let value else {
            let alert = NSAlert()
            alert.messageText = "Width must be a whole number from \(widthRange.lowerBound) to \(widthRange.upperBound)."
            alert.informativeText = "Select Unwrap to join each paragraph and list item onto one line."
            alert.runModal()
            widthField.selectText(nil)
            return
        }

        options = WrapOptions(
            width: value == 0 ? options.width : value,
            unwrap: unwrap || value == 0,
            repair: repairButton.state == .on,
            indentation: ListIndentation.allCases.first { $0.menuTag == indentationMenu.selectedTag() } ?? .preserve
        )
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
guard arguments.count == 4 || arguments.count == 8,
      let width = Int(arguments[1]),
      let minimum = Int(arguments[2]),
      let maximum = Int(arguments[3]),
      minimum >= 0, maximum > 0, minimum <= width, width <= maximum else {
    fail("Usage: HardWrapDialog WIDTH MINIMUM MAXIMUM [UNWRAP REPAIR INDENT VERSION]")
}

let widthRange = minimum...maximum
let initialWidth = width == 0 ? min(70, maximum) : width
var options = WrapOptions(width: initialWidth, unwrap: width == 0)
var formatterVersion = ""
if arguments.count == 8 {
    guard ["0", "1"].contains(arguments[4]), ["0", "1"].contains(arguments[5]),
          let indentation = ListIndentation(rawValue: arguments[6]) else {
        fail("Expected 0 or 1 for Unwrap and Repair, and preserve, spaces, or tabs for indentation.")
    }
    options.unwrap = options.unwrap || arguments[4] == "1"
    options.repair = arguments[5] == "1"
    options.indentation = indentation
    formatterVersion = arguments[7]
    if let version = formatterVersion.split(separator: " ").last {
        formatterVersion = "v\(version)"
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let nibURL = URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("HardWrapDialog.nib")
guard let nibData = try? Data(contentsOf: nibURL) else {
    fail("Could not read HardWrapDialog.nib beside the helper.")
}

let nib = NSNib(nibData: nibData, bundle: nil)
let controller = HardWrapDialogController(options: options, widthRange: widthRange)
var topLevelObjects: NSArray?
guard nib.instantiate(withOwner: controller, topLevelObjects: &topLevelObjects),
      let window = controller.window,
      controller.widthField != nil, controller.unwrapButton != nil,
      controller.repairButton != nil, controller.indentationMenu != nil,
      controller.versionLabel != nil else {
    fail("Could not load HardWrapDialog.nib or connect its outlets.")
}

controller.configure(formatterVersion: formatterVersion)
application.activate(ignoringOtherApps: true)

let response = withExtendedLifetime(topLevelObjects) {
    application.runModal(for: window)
}
window.orderOut(nil)
print(response == .OK ? controller.options.result : "cancel")
