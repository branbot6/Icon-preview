import AppKit
import Foundation
import UniformTypeIdentifiers
import WebKit

private let appDisplayName = "Icon Preview Lab"
private let appVersion = "1.1.0"
private let appShortVersion = "1.1"

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
  private var window: NSWindow?
  private var webView: WKWebView?

  func applicationDidFinishLaunching(_ notification: Notification) {
    setupMenu()
    createWindow()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  private func setupMenu() {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)

    let appMenu = NSMenu(title: appDisplayName)
    appMenu.addItem(withTitle: "About \(appDisplayName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    appMenuItem.submenu = appMenu
    NSApp.mainMenu = mainMenu
  }

  private func createWindow() {
    let config = WKWebViewConfiguration()
    let contentController = WKUserContentController()

    contentController.add(self, name: "nativeBridge")
    contentController.addUserScript(WKUserScript(source: bridgeBootstrapScript(), injectionTime: .atDocumentStart, forMainFrameOnly: false))
    config.userContentController = contentController

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.setValue(false, forKey: "drawsBackground")
    // Let desktop app open external links (e.g. GitHub/LinkedIn) in system browser.
    webView.uiDelegate = self
    webView.navigationDelegate = self
    self.webView = webView

    let win = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1320, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    win.title = appDisplayName
    win.minSize = NSSize(width: 1080, height: 760)
    win.center()
    win.isReleasedWhenClosed = false
    win.contentView = webView
    self.window = win

    if let iconURL = locateResource("ip-icon-1024.png"), let iconImage = NSImage(contentsOf: iconURL) {
      NSApp.applicationIconImage = iconImage
    }

    if let indexURL = locateResource("index.html") {
      webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
    } else {
      webView.loadHTMLString("<html><body><h1>index.html not found</h1></body></html>", baseURL: nil)
    }

    win.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func bridgeBootstrapScript() -> String {
    """
    (() => {
      if (window.desktopBridge && window.desktopBridge.isDesktop) return;

      // Track async bridge calls so native can resolve/reject by id.
      const pending = new Map();

      window.__nativeBridgeResolve = (id, value) => {
        const item = pending.get(id);
        if (!item) return;
        pending.delete(id);
        item.resolve(value);
      };

      window.__nativeBridgeReject = (id, message) => {
        const item = pending.get(id);
        if (!item) return;
        pending.delete(id);
        item.reject(new Error(message || "Native bridge error"));
      };

      // Shared request envelope used by all desktop bridge methods.
      const invoke = (method, payload) => new Promise((resolve, reject) => {
        const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
        pending.set(id, { resolve, reject });
        try {
          window.webkit.messageHandlers.nativeBridge.postMessage({ id, method, payload: payload || {} });
        } catch (err) {
          pending.delete(id);
          reject(err);
        }
      });

      window.desktopBridge = {
        isDesktop: true,
        pickSvgFile: () => invoke("pickSvgFile", {}),
        exportPng: (payload) => invoke("exportPng", payload || {}),
        exportMacDmg: (payload) => invoke("exportMacDmg", payload || {}),
      };
    })();
    """
  }

  private func shouldOpenExternally(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https" || scheme == "mailto"
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    // Handle target="_blank" links by sending them to the default browser.
    if navigationAction.targetFrame == nil, let url = navigationAction.request.url, shouldOpenExternally(url) {
      NSWorkspace.shared.open(url)
    }
    return nil
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard navigationAction.navigationType == .linkActivated,
          let url = navigationAction.request.url else {
      decisionHandler(.allow)
      return
    }

    if shouldOpenExternally(url) {
      NSWorkspace.shared.open(url)
      decisionHandler(.cancel)
      return
    }

    decisionHandler(.allow)
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard message.name == "nativeBridge" else { return }
    guard let body = message.body as? [String: Any],
          let id = body["id"] as? String,
          let method = body["method"] as? String else {
      return
    }

    // File dialogs and save panels must run on the main actor.
    switch method {
    case "pickSvgFile":
      Task { @MainActor in
        do {
          let result = try pickSvgFile()
          resolveBridgeCall(id: id, value: result)
        } catch {
          rejectBridgeCall(id: id, message: error.localizedDescription)
        }
      }
    case "exportPng":
      Task { @MainActor in
        do {
          let payload = body["payload"] as? [String: Any] ?? [:]
          let result = try exportPng(payload: payload)
          resolveBridgeCall(id: id, value: result)
        } catch {
          rejectBridgeCall(id: id, message: error.localizedDescription)
        }
      }
    case "exportMacDmg":
      Task { @MainActor in
        do {
          let payload = body["payload"] as? [String: Any] ?? [:]
          let result = try exportMacDmg(payload: payload)
          resolveBridgeCall(id: id, value: result)
        } catch {
          rejectBridgeCall(id: id, message: error.localizedDescription)
        }
      }
    default:
      rejectBridgeCall(id: id, message: "Unsupported method: \(method)")
    }
  }

  private func resolveBridgeCall(id: String, value: Any) {
    callBridgeCallback(function: "__nativeBridgeResolve", id: id, payload: value)
  }

  private func rejectBridgeCall(id: String, message: String) {
    callBridgeCallback(function: "__nativeBridgeReject", id: id, payload: message)
  }

  private func callBridgeCallback(function: String, id: String, payload: Any) {
    guard let webView else { return }
    guard let idJSON = jsonString(id), let payloadJSON = jsonString(payload) else { return }
    let script = "window.\(function)(\(idJSON), \(payloadJSON));"
    webView.evaluateJavaScript(script)
  }

  private func jsonString(_ value: Any) -> String? {
    if let str = value as? String {
      guard let data = try? JSONSerialization.data(withJSONObject: [str], options: []),
            var encoded = String(data: data, encoding: .utf8) else {
        return nil
      }
      encoded.removeFirst()
      encoded.removeLast()
      return encoded
    }

    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: []),
          let encoded = String(data: data, encoding: .utf8) else {
      return nil
    }
    return encoded
  }

  @MainActor
  private func pickSvgFile() throws -> [String: Any] {
    // Prefer native picker in desktop mode to avoid WebKit file input quirks.
    let panel = NSOpenPanel()
    panel.title = "Choose SVG"
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.svg]

    guard panel.runModal() == .OK, let fileURL = panel.url else {
      return ["canceled": true]
    }

    let data = try Data(contentsOf: fileURL)
    let text = String(decoding: data, as: UTF8.self)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? data.count

    return [
      "canceled": false,
      "filePath": fileURL.path,
      "name": fileURL.lastPathComponent,
      "size": fileSize,
      "text": text,
      "base64": data.base64EncodedString(),
    ]
  }

  @MainActor
  private func exportPng(payload: [String: Any]) throws -> [String: Any] {
    // Receive a PNG data URL from JS and write it through a native save panel.
    guard let pngDataUrl = payload["pngDataUrl"] as? String,
          pngDataUrl.hasPrefix("data:image/png;base64,") else {
      throw NSError(domain: "IconPreviewLab", code: 10, userInfo: [NSLocalizedDescriptionKey: "Invalid PNG data."])
    }

    let requestedName = payload["fileName"] as? String
    let fallbackName = "\(safeName(payload["appName"] as? String))-1024.png"
    let finalName = safeFileName(requestedName) ?? fallbackName

    let savePanel = NSSavePanel()
    savePanel.title = "Export 1024 PNG"
    savePanel.nameFieldStringValue = finalName
    if #available(macOS 11.0, *) {
      savePanel.allowedContentTypes = [.png]
    } else {
      savePanel.allowedFileTypes = ["png"]
    }

    guard savePanel.runModal() == .OK, let outputURL = savePanel.url else {
      return ["canceled": true]
    }

    let base64 = pngDataUrl.replacingOccurrences(of: "data:image/png;base64,", with: "")
    guard let pngData = Data(base64Encoded: base64) else {
      throw NSError(domain: "IconPreviewLab", code: 11, userInfo: [NSLocalizedDescriptionKey: "Unable to decode PNG data."])
    }

    try pngData.write(to: outputURL)
    return ["canceled": false, "filePath": outputURL.path]
  }

  private func safeFileName(_ value: String?) -> String? {
    // Keep user-facing names readable while removing unsafe filesystem characters.
    guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
      return nil
    }
    let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: " ._-"))
    let cleaned = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return nil }
    return cleaned
  }

  @MainActor
  private func exportMacDmg(payload: [String: Any]) throws -> [String: Any] {
    // Build a temporary .app bundle, then package it into a distributable DMG.
    guard let pngDataUrl = payload["pngDataUrl"] as? String,
          pngDataUrl.hasPrefix("data:image/png;base64,") else {
      throw NSError(domain: "IconPreviewLab", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid icon data."])
    }

    let rawAppName = payload["appName"] as? String
    let finalAppName = safeName(rawAppName)

    let savePanel = NSSavePanel()
    savePanel.title = "Export macOS DMG"
    if let dmgType = UTType(filenameExtension: "dmg") {
      savePanel.allowedContentTypes = [dmgType]
    }
    savePanel.nameFieldStringValue = "\(finalAppName).dmg"
    savePanel.canCreateDirectories = true
    if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
      savePanel.directoryURL = downloads
    }

    guard savePanel.runModal() == .OK, let saveURL = savePanel.url else {
      return ["canceled": true]
    }

    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("icon-preview-lab-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: tempRoot)
    }

    let iconPng = tempRoot.appendingPathComponent("icon.png")
    let iconIcns = tempRoot.appendingPathComponent("icon.icns")
    let stageDir = tempRoot.appendingPathComponent("stage")
    try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)

    let base64 = pngDataUrl.replacingOccurrences(of: "data:image/png;base64,", with: "")
    guard let pngData = Data(base64Encoded: base64) else {
      throw NSError(domain: "IconPreviewLab", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode PNG data."])
    }
    try pngData.write(to: iconPng)

    try buildIcns(pngPath: iconPng, icnsPath: iconIcns, workDir: tempRoot)
    let appBundle = try buildPreviewApp(stageDir: stageDir, appName: finalAppName, icnsPath: iconIcns)

    let applicationsAlias = stageDir.appendingPathComponent("Applications")
    if !FileManager.default.fileExists(atPath: applicationsAlias.path) {
      try? FileManager.default.createSymbolicLink(atPath: applicationsAlias.path, withDestinationPath: "/Applications")
    }

    if FileManager.default.fileExists(atPath: saveURL.path) {
      try FileManager.default.removeItem(at: saveURL)
    }

    try runCommand(
      "/usr/bin/hdiutil",
      args: [
        "create",
        "-volname", finalAppName,
        "-srcfolder", stageDir.path,
        "-ov",
        "-format", "UDZO",
        saveURL.path,
      ]
    )

    return [
      "canceled": false,
      "filePath": saveURL.path,
      "appBundleName": appBundle.lastPathComponent,
    ]
  }

  private func buildIcns(pngPath: URL, icnsPath: URL, workDir: URL) throws {
    let iconsetPath = workDir.appendingPathComponent("icon.iconset")
    try FileManager.default.createDirectory(at: iconsetPath, withIntermediateDirectories: true)

    let sizes: [(String, Int)] = [
      ("icon_16x16.png", 16),
      ("icon_16x16@2x.png", 32),
      ("icon_32x32.png", 32),
      ("icon_32x32@2x.png", 64),
      ("icon_128x128.png", 128),
      ("icon_128x128@2x.png", 256),
      ("icon_256x256.png", 256),
      ("icon_256x256@2x.png", 512),
      ("icon_512x512.png", 512),
      ("icon_512x512@2x.png", 1024),
    ]

    for (file, size) in sizes {
      let out = iconsetPath.appendingPathComponent(file)
      try runCommand(
        "/usr/bin/sips",
        args: [
          "-z", String(size), String(size),
          pngPath.path,
          "--out", out.path,
        ]
      )
    }

    try runCommand(
      "/usr/bin/iconutil",
      args: [
        "-c", "icns",
        iconsetPath.path,
        "-o", icnsPath.path,
      ]
    )
  }

  private func buildPreviewApp(stageDir: URL, appName: String, icnsPath: URL) throws -> URL {
    let appBundle = stageDir.appendingPathComponent("\(appName).app")
    let contents = appBundle.appendingPathComponent("Contents")
    let macos = contents.appendingPathComponent("MacOS")
    let resources = contents.appendingPathComponent("Resources")

    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

    let execName = appName.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    let execPath = macos.appendingPathComponent(execName)

    let infoPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key><string>en</string>
      <key>CFBundleDisplayName</key><string>\(appName)</string>
      <key>CFBundleExecutable</key><string>\(execName)</string>
      <key>CFBundleIconFile</key><string>AppIcon</string>
      <key>CFBundleIdentifier</key><string>org.branai.preview.\(execName.lowercased())</string>
      <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
      <key>CFBundleName</key><string>\(appName)</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleShortVersionString</key><string>\(appShortVersion)</string>
      <key>CFBundleVersion</key><string>\(appVersion)</string>
    </dict>
    </plist>
    """

    try infoPlist.write(to: contents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
    try FileManager.default.copyItem(at: icnsPath, to: resources.appendingPathComponent("AppIcon.icns"))

    if let logoSource = locateResource("branai-logo.svg") {
      try? FileManager.default.copyItem(at: logoSource, to: resources.appendingPathComponent("branai-logo.svg"))
    }

    let promoHtml = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <title>BranAI</title>
      <style>
        :root { color-scheme: light; }
        html, body { margin: 0; height: 100%; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; background: #f6f7fb; color: #111; }
        .wrap { min-height: 100%; display: grid; place-items: center; padding: 24px; }
        .card { width: min(720px, 100%); background: #fff; border: 1px solid rgba(0,0,0,0.08); border-radius: 16px; padding: 28px; text-align: center; box-shadow: 0 16px 34px rgba(17,24,39,0.1); }
        .logo { width: min(440px, 92%); height: auto; display: block; margin: 0 auto 18px; }
        .link { font-size: 22px; line-height: 1.25; font-weight: 600; letter-spacing: 0.01em; color: #111; text-decoration: none; }
        .link:hover { text-decoration: underline; }
      </style>
    </head>
    <body>
      <main class="wrap">
        <section class="card">
          <img class="logo" src="./branai-logo.svg" alt="BranAI logo" />
          <a class="link" href="https://www.branai.org">www.branai.org</a>
        </section>
      </main>
    </body>
    </html>
    """

    let promoHTMLPath = resources.appendingPathComponent("branai-promo.html")
    try promoHtml.write(to: promoHTMLPath, atomically: true, encoding: .utf8)

    let swiftSourcePath = stageDir.appendingPathComponent("\(execName)-promo.swift")
    let escapedTitle = escapeSwiftString(appName)
    let swiftSource = """
    import Cocoa
    import WebKit

    final class AppDelegate: NSObject, NSApplicationDelegate {
      private var window: NSWindow!

      func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 920, height: 620)
        window = NSWindow(
          contentRect: frame,
          styleMask: [.titled, .closable, .miniaturizable, .resizable],
          backing: .buffered,
          defer: false
        )
        window.center()
        window.title = "\(escapedTitle)"
        window.isReleasedWhenClosed = false

        let webView = WKWebView(frame: window.contentView?.bounds ?? .zero)
        webView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(webView)

        if let resourcePath = Bundle.main.resourcePath {
          let baseURL = URL(fileURLWithPath: resourcePath, isDirectory: true)
          let pageURL = baseURL.appendingPathComponent("branai-promo.html")
          if FileManager.default.fileExists(atPath: pageURL.path) {
            webView.loadFileURL(pageURL, allowingReadAccessTo: baseURL)
          } else {
            webView.loadHTMLString("<html><body><h1>BranAI</h1><p>www.branai.org</p></body></html>", baseURL: nil)
          }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
      }

      func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
      }
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
    """

    try swiftSource.write(to: swiftSourcePath, atomically: true, encoding: .utf8)

    var nativeBuilt = false
    do {
      try runCommand(
        "/usr/bin/xcrun",
        args: [
          "swiftc",
          "-O",
          "-framework", "Cocoa",
          "-framework", "WebKit",
          swiftSourcePath.path,
          "-o", execPath.path,
        ]
      )
      nativeBuilt = true
    } catch {
      nativeBuilt = false
    }

    if !nativeBuilt {
      let fallbackTitle = appName
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      let fallbackScript = """
      #!/bin/bash
      /usr/bin/osascript -e "display dialog \"BranAI\\nwww.branai.org\" buttons {\"OK\"} default button \"OK\" with title \"\(fallbackTitle)\""
      exit 0
      """
      try fallbackScript.write(to: execPath, atomically: true, encoding: .utf8)
    }

    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execPath.path)
    return appBundle
  }

  private func runCommand(_ command: String, args: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = args

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      let errData = stderr.fileHandleForReading.readDataToEndOfFile()
      let outData = stdout.fileHandleForReading.readDataToEndOfFile()
      let errText = String(data: errData, encoding: .utf8) ?? ""
      let outText = String(data: outData, encoding: .utf8) ?? ""
      let merged = [errText, outText].filter { !$0.isEmpty }.joined(separator: "\n")
      throw NSError(
        domain: "IconPreviewLab",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: merged.isEmpty ? "\(command) failed with exit code \(process.terminationStatus)" : merged]
      )
    }
  }

  private func safeName(_ input: String?) -> String {
    let raw = (input ?? "YourApp").trimmingCharacters(in: .whitespacesAndNewlines)
    let clean = raw.replacingOccurrences(of: "[^a-zA-Z0-9 _-]", with: "", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return clean.isEmpty ? "YourApp" : clean
  }

  private func escapeSwiftString(_ input: String) -> String {
    input
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
  }

  private func locateResource(_ fileName: String) -> URL? {
    let fm = FileManager.default

    let candidatePaths: [URL] = [
      Bundle.main.resourceURL?.appendingPathComponent(fileName),
      Bundle.module.resourceURL?.appendingPathComponent(fileName),
      Bundle.module.resourceURL?.appendingPathComponent("Resources").appendingPathComponent(fileName),
      URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")
        .appendingPathComponent(fileName),
      URL(fileURLWithPath: fm.currentDirectoryPath)
        .appendingPathComponent("native-macos")
        .appendingPathComponent("Sources")
        .appendingPathComponent("IconPreviewLabNative")
        .appendingPathComponent("Resources")
        .appendingPathComponent(fileName),
    ].compactMap { $0 }

    for path in candidatePaths where fm.fileExists(atPath: path.path) {
      return path
    }
    return nil
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
