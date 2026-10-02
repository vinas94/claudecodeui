// CloudCLI.app: starts this checkout's server, shows it in native WebKit windows,
// and stops the server again on quit. Modelled on the mobile.de scraper launcher.
import AppKit
import WebKit

let appName = "CloudCLI"

// Paths are baked into Info.plist by `just install`, so moving the repo only needs a
// re-install rather than a rebuild.
let info = Bundle.main.infoDictionary ?? [:]
let projectDir = info["CCProject"] as? String ?? ""
let configPath = info["CCConfig"] as? String ?? ""
let port = info["CCPort"] as? Int ?? 3001
let rootURL = URL(string: "http://127.0.0.1:\(port)/")!
let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/cloudcli.log")

/// True once something is listening on the app's port.
func serverIsUp() -> Bool {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }

    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = UInt16(port).bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")

    let ok = withUnsafePointer(to: &addr) { raw in
        raw.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return ok == 0
}

/// Every descendant of `root`: zsh -> npm -> node -> the claude processes it spawns.
func descendants(of root: pid_t) -> [pid_t] {
    let p = Process()
    let out = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/ps")
    p.arguments = ["-A", "-o", "pid=,ppid="]
    p.standardOutput = out
    guard (try? p.run()) != nil else { return [] }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()

    var children: [pid_t: [pid_t]] = [:]
    for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
        let cols = line.split(separator: " ").compactMap { pid_t($0) }
        if cols.count == 2 { children[cols[1], default: []].append(cols[0]) }
    }
    var found: [pid_t] = []
    var queue = [root]
    while let next = queue.popLast() {
        for child in children[next] ?? [] {
            found.append(child)
            queue.append(child)
        }
    }
    return found
}

let startingPage = """
<html><body style="font: 15px -apple-system; color: #888; display: flex; height: 100vh;
margin: 0; align-items: center; justify-content: center">Starting CloudCLI…</body></html>
"""

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    /// Set only when this app started the server, so quitting never stops one it merely attached to.
    private var server: Process?
    private var windows: [NSWindow] = []
    private var ready = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        let first = openWindow(nil)

        if serverIsUp() {           // already serving, nothing to start
            ready = true
            first.load(URLRequest(url: rootURL))
            return
        }
        first.loadHTMLString(startingPage, baseURL: nil)
        startServer()
        poll(first)
    }

    private func startServer() {
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let p = Process()
        // a login shell, because launched from Finder we'd otherwise get launchd's minimal
        // PATH; the nix-managed config is exported so it beats CloudCLI's own .env lookup
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "set -a; . '\(configPath)'; set +a; exec npm run server"]
        p.currentDirectoryURL = URL(fileURLWithPath: projectDir)

        if let log = try? FileHandle(forWritingTo: logURL) {
            log.seekToEndOfFile()
            p.standardOutput = log
            p.standardError = log
        }

        do {
            try p.run()
            server = p
        } catch {
            fail("Could not start the server: \(error.localizedDescription)")
        }
    }

    private func poll(_ view: WKWebView) {
        let deadline = Date().addingTimeInterval(60)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            if serverIsUp() {
                timer.invalidate()
                self.ready = true
                view.load(URLRequest(url: rootURL))
            } else if let s = self.server, !s.isRunning {
                timer.invalidate()
                self.fail("The server exited during startup.\n\n\(logURL.path) has the output.")
            } else if Date() > deadline {
                timer.invalidate()
                self.fail("The server didn't come up within 60 seconds.\n\n\(logURL.path) has the output.")
            }
        }
    }

    /// A new window showing `url`, or the root page when nil. WebKit hands its own
    /// configuration to popups; that one must be used for the popup's web view.
    @discardableResult
    private func openWindow(_ url: URL?, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) -> WKWebView {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        w.title = appName
        w.isReleasedWhenClosed = false
        if windows.isEmpty {
            w.setFrameAutosaveName("main")
            if w.frame.origin == .zero { w.center() }
        } else if let last = windows.last {
            w.setFrame(last.frame, display: false)
            w.setFrameTopLeftPoint(w.cascadeTopLeft(from: NSPoint(x: last.frame.minX, y: last.frame.maxY)))
        }

        let view = WKWebView(frame: w.contentLayoutRect, configuration: configuration)
        view.autoresizingMask = [.width, .height]
        view.allowsBackForwardNavigationGestures = true
        view.isInspectable = true   // Safari > Develop, for debugging the UI
        view.navigationDelegate = self
        view.uiDelegate = self
        if let url { view.load(URLRequest(url: url)) }
        w.contentView = view

        windows.append(w)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return view
    }

    private func isLocal(_ url: URL?) -> Bool {
        url?.host == "127.0.0.1" || url?.host == "localhost"
    }

    /// Hands anything that isn't our own server to the real browser. True when it did.
    private func openExternally(_ target: URL?) -> Bool {
        guard let target, let scheme = target.scheme?.lowercased(),
              scheme == "http" || scheme == "https", !isLocal(target)
        else { return false }
        NSWorkspace.shared.open(target)
        return true
    }

    // ---- web view behaviour ------------------------------------------------ #

    /// Plain links to other sites: cancel the in-app navigation and hand it to the browser.
    func webView(_ webView: WKWebView,
                 decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let external = action.navigationType == .linkActivated && openExternally(action.request.url)
        decisionHandler(external ? .cancel : .allow)
    }

    /// target="_blank" / window.open: our own pages (e.g. /session/<id>) get a new app
    /// window, which is what "open in a new tab" means here; anything else goes to the browser.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if openExternally(action.request.url) { return nil }
        return openWindow(nil, configuration: configuration)
    }

    func webViewDidClose(_ webView: WKWebView) {
        webView.window?.close()
    }

    /// <input type="file">: WebKit shows nothing unless the host provides the panel.
    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.begin { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    // alert / confirm / prompt: without these WebKit silently returns false or nil,
    // so "Delete session?" style confirmations would never go through.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
    }

    // ---- app lifecycle ----------------------------------------------------- #

    private func fail(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "\(appName) didn't start"
        alert.informativeText = message
        alert.runModal()
        NSApp.terminate(nil)
    }

    /// Quitting takes down the whole tree this app started (zsh, npm, node and any running
    /// claude turns): TERM first, KILL whatever is still alive two seconds later.
    func applicationWillTerminate(_ notification: Notification) {
        guard let s = server, s.isRunning else { return }
        let tree = [s.processIdentifier] + descendants(of: s.processIdentifier)
        for pid in tree { kill(pid, SIGTERM) }
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, tree.contains(where: { kill($0, 0) == 0 }) {
            usleep(100_000)
        }
        for pid in tree where kill(pid, 0) == 0 { kill(pid, SIGKILL) }
    }

    // closing the last window leaves the app and the server running, as any Mac app does
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { newWindow() }
        return true
    }

    @objc private func newWindow() {
        windows.removeAll { !$0.isVisible && !$0.isMiniaturized }
        let view = openWindow(nil)
        if ready { view.load(URLRequest(url: rootURL)) } else { view.loadHTMLString(startingPage, baseURL: nil) }
    }

    @objc private func reload() {
        (NSApp.keyWindow?.contentView as? WKWebView)?.reload()
    }

    private func buildMenu() {
        func submenu(_ title: String, _ items: [(String, Selector, String)]) -> NSMenuItem {
            let item = NSMenuItem()
            let menu = NSMenu(title: title)
            for (name, action, key) in items {
                menu.addItem(withTitle: name, action: action, keyEquivalent: key)
            }
            item.submenu = menu
            return item
        }

        let main = NSMenu()
        main.addItem(submenu(appName, [
            ("Hide \(appName)", #selector(NSApplication.hide(_:)), "h"),
            ("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q"),
        ]))
        main.addItem(submenu("File", [
            ("New Window", #selector(newWindow), "n"),
            ("Close", #selector(NSWindow.performClose(_:)), "w"),
            ("Reload", #selector(reload), "r"),
        ]))
        main.addItem(submenu("Edit", [
            ("Undo", Selector(("undo:")), "z"),
            ("Redo", Selector(("redo:")), "Z"),   // capital = ⇧⌘Z
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a"),
        ]))
        main.addItem(submenu("Window", [
            ("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
        ]))
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
