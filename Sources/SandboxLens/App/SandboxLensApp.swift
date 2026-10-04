import AppKit
import SwiftUI

final class SandboxLensAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SandboxLensApp: App {
    @NSApplicationDelegateAdaptor(SandboxLensAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Sandbox Lens", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 1060, minHeight: 680)
                .task {
                    await model.bootstrap()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan This Mac") {
                    Task {
                        await model.scanThisMac()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.isScanning)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
