import AppKit
import ServiceManagement

// MARK: - Idioma / Language

enum Lang {
    static let d = UserDefaults.standard

    static var current: String {
        get {
            if let v = d.string(forKey: "language") { return v }
            let sys = Locale.preferredLanguages.first ?? "en"
            return sys.hasPrefix("pt") ? "pt" : "en"
        }
        set { d.set(newValue, forKey: "language") }
    }

    static var isPT: Bool { current == "pt" }

    static func t(_ pt: String, _ en: String) -> String { isPT ? pt : en }
}

// MARK: - Preferências

enum Pref {
    static let d = UserDefaults.standard

    static var workMinutes: Int {
        get { let v = d.integer(forKey: "workMinutes"); return v > 0 ? v : 20 }
        set { d.set(newValue, forKey: "workMinutes") }
    }
    static var breakSeconds: Int {
        get { let v = d.integer(forKey: "breakSeconds"); return v > 0 ? v : 20 }
        set { d.set(newValue, forKey: "breakSeconds") }
    }
    static var fullScreenBreak: Bool {
        get { d.object(forKey: "fullScreenBreak") == nil ? true : d.bool(forKey: "fullScreenBreak") }
        set { d.set(newValue, forKey: "fullScreenBreak") }
    }
    static var launchAtLogin: Bool {
        get { d.bool(forKey: "launchAtLogin") }
        set { d.set(newValue, forKey: "launchAtLogin") }
    }
    static var didSetup: Bool {
        get { d.bool(forKey: "didSetup") }
        set { d.set(newValue, forKey: "didSetup") }
    }
}

// MARK: - Vista da pausa (clique para saltar)

final class BreakView: NSView {
    var onClick: (() -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    enum Phase { case work, rest }

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()

    var phase: Phase = .work
    var paused = false
    var remaining: TimeInterval = 20 * 60
    var lastTick = Date()
    var timer: Timer?

    var overlayWindows: [NSWindow] = []
    var countdownLabels: [NSTextField] = []

    // MARK: Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        configureStatusItem()

        menu.delegate = self
        statusItem.menu = menu

        // Primeira execução: arranca com o Mac, para os lembretes não se perderem num reinício.
        if !Pref.didSetup {
            Pref.didSetup = true
            Pref.launchAtLogin = true
            applyLoginItem(true)
        }

        remaining = TimeInterval(Pref.workMinutes * 60)
        lastTick = Date()

        let t = Timer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)

        updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        closeOverlay()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "eye", accessibilityDescription: "Pausa 20-20-20")
        img?.isTemplate = true
        button.image = img
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        button.toolTip = "Pausa 20-20-20"
    }

    // MARK: Relógio

    @objc func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now

        guard !paused else { return }
        guard dt < 10 else { return } // voltou de suspensão: não conta o tempo parado

        remaining = max(0, remaining - dt)

        if remaining <= 0 {
            if phase == .work { startBreak(auto: true) } else { finishBreak() }
        } else {
            updateStatusItem()
            updateCountdownLabels()
        }
    }

    @objc func systemDidWake() {
        closeOverlay()
        phase = .work
        paused = false
        remaining = TimeInterval(Pref.workMinutes * 60)
        lastTick = Date()
        updateStatusItem()
    }

    // MARK: Controlo

    func startBreak(auto: Bool) {
        phase = .rest
        paused = false
        remaining = TimeInterval(Pref.breakSeconds)
        lastTick = Date()
        showBreakUI()
        updateStatusItem()
    }

    func finishBreak() {
        closeOverlay()
        phase = .work
        paused = false
        remaining = TimeInterval(Pref.workMinutes * 60)
        lastTick = Date()
        updateStatusItem()
    }

    func resetCycle() {
        closeOverlay()
        phase = .work
        paused = false
        remaining = TimeInterval(Pref.workMinutes * 60)
        lastTick = Date()
        updateStatusItem()
    }

    func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let symbol: String
        let text: String

        if paused {
            symbol = "pause.circle"
            text = ""
        } else if phase == .rest {
            symbol = "eye.fill"
            text = "\(Int(ceil(remaining)))s"
        } else {
            symbol = "eye"
            let mins = max(1, Int(ceil(remaining / 60)))
            text = "\(mins)m"
        }

        if button.image?.name() != symbol {
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Pausa 20-20-20")
            img?.isTemplate = true
            button.image = img
        }
        button.title = text.isEmpty ? "" : " " + text

        let next = Date().addingTimeInterval(remaining)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        button.toolTip = phase == .rest && !paused
            ? Lang.t("A descansar os olhos — \(Int(ceil(remaining))) s",
                     "Resting your eyes — \(Int(ceil(remaining))) s")
            : Lang.t("Pausa 20-20-20 — próxima pausa às \(f.string(from: next))",
                     "20-20-20 break — next break at \(f.string(from: next))")
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: statusDescription(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if paused {
            menu.addItem(item(Lang.t("Retomar lembretes", "Resume reminders"), #selector(togglePause)))
            menu.addItem(item(Lang.t("Reiniciar ciclo", "Restart cycle"), #selector(reset)))
        } else if phase == .rest {
            menu.addItem(item(Lang.t("Saltar pausa", "Skip break"), #selector(skipBreak)))
            menu.addItem(item(Lang.t("Reiniciar ciclo", "Restart cycle"), #selector(reset)))
        } else {
            menu.addItem(item(Lang.t("Pausar lembretes", "Pause reminders"), #selector(togglePause)))
            menu.addItem(item(Lang.t("Fazer uma pausa agora", "Take a break now"), #selector(breakNow)))
            menu.addItem(item(Lang.t("Reiniciar ciclo", "Restart cycle"), #selector(reset)))
        }

        menu.addItem(.separator())

        // Duração do trabalho
        let workItem = NSMenuItem(title: Lang.t("Tempo de trabalho", "Work time"), action: nil, keyEquivalent: "")
        let workMenu = NSMenu()
        for m in [10, 15, 20, 25, 30, 45, 60] {
            let i = item(Lang.t("\(m) minutos", "\(m) minutes"), #selector(setWork(_:)))
            i.tag = m
            i.state = (m == Pref.workMinutes) ? .on : .off
            workMenu.addItem(i)
        }
        workItem.submenu = workMenu
        menu.addItem(workItem)

        // Duração da pausa
        let restItem = NSMenuItem(title: Lang.t("Duração da pausa", "Break length"), action: nil, keyEquivalent: "")
        let restMenu = NSMenu()
        for s in [20, 30, 45, 60] {
            let i = item(Lang.t("\(s) segundos", "\(s) seconds"), #selector(setBreak(_:)))
            i.tag = s
            i.state = (s == Pref.breakSeconds) ? .on : .off
            restMenu.addItem(i)
        }
        restItem.submenu = restMenu
        menu.addItem(restItem)

        menu.addItem(.separator())

        let full = item(Lang.t("Pausa em ecrã inteiro", "Full-screen break"), #selector(toggleFullScreen))
        full.state = Pref.fullScreenBreak ? .on : .off
        menu.addItem(full)

        let login = item(Lang.t("Iniciar com o Mac", "Launch at login"), #selector(toggleLogin))
        login.state = loginItemEnabled ? .on : .off
        menu.addItem(login)

        // Idioma
        let langItem = NSMenuItem(title: Lang.t("Idioma", "Language"), action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        let pt = item("Português", #selector(setLanguage(_:)))
        pt.tag = 0
        pt.state = Lang.isPT ? .on : .off
        langMenu.addItem(pt)
        let en = item("English", #selector(setLanguage(_:)))
        en.tag = 1
        en.state = Lang.isPT ? .off : .on
        langMenu.addItem(en)
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())
        menu.addItem(item(Lang.t("Acerca da Pausa 20-20-20", "About Pausa 20-20-20"), #selector(about)))
        menu.addItem(item(Lang.t("Sair", "Quit"), #selector(quit)))

        updateStatusItem()
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    private func statusDescription() -> String {
        if paused { return Lang.t("Lembretes em pausa", "Reminders paused") }
        if phase == .rest {
            return Lang.t("Pausa a decorrer: \(Int(ceil(remaining))) s",
                          "Break in progress: \(Int(ceil(remaining))) s")
        }
        let mins = Int(ceil(remaining / 60))
        return Lang.t("Próxima pausa em \(mins) min", "Next break in \(mins) min")
    }

    @objc func togglePause() {
        if phase == .rest {
            closeOverlay()
            phase = .work
            remaining = TimeInterval(Pref.workMinutes * 60)
        } else {
            paused.toggle()
        }
        lastTick = Date()
        updateStatusItem()
    }

    @objc func skipBreak() { finishBreak() }

    @objc func breakNow() {
        if phase == .rest { closeOverlay() }
        startBreak(auto: false)
    }

    @objc func reset() { resetCycle() }

    @objc func setWork(_ sender: NSMenuItem) {
        Pref.workMinutes = sender.tag
        if phase == .work && !paused {
            remaining = TimeInterval(Pref.workMinutes * 60)
            lastTick = Date()
        }
        updateStatusItem()
    }

    @objc func setBreak(_ sender: NSMenuItem) {
        Pref.breakSeconds = sender.tag
        if phase == .rest && !paused {
            remaining = TimeInterval(Pref.breakSeconds)
            lastTick = Date()
            updateCountdownLabels()
        }
    }

    @objc func toggleFullScreen() {
        Pref.fullScreenBreak.toggle()
    }

    @objc func setLanguage(_ sender: NSMenuItem) {
        let new = sender.tag == 1 ? "en" : "pt"
        guard new != Lang.current else { return }
        Lang.current = new

        for i in sender.menu?.items ?? [] {
            i.state = (i.tag == sender.tag) ? .on : .off
        }
        updateStatusItem()

        // Se a pausa estiver a decorrer, redesenha-a no novo idioma.
        if phase == .rest && !paused {
            let rem = remaining
            showBreakUI()
            remaining = rem
            updateCountdownLabels()
            lastTick = Date()
        }
    }

    // MARK: Iniciar com o Mac

    var loginItemEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @objc func toggleLogin() {
        let target = !loginItemEnabled
        applyLoginItem(target)
        Pref.launchAtLogin = target
    }

    func applyLoginItem(_ on: Bool) {
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Pausa20: erro no item de início de sessão: \(error)")
        }
    }

    // MARK: Pausa visual

    func showBreakUI() {
        closeOverlay()
        let compact = !Pref.fullScreenBreak
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        if compact, let main = NSScreen.main ?? screens.first {
            let size = NSSize(width: 380, height: 150)
            let vf = main.visibleFrame
            let frame = NSRect(x: vf.maxX - size.width - 20,
                               y: vf.maxY - size.height - 20,
                               width: size.width, height: size.height)
            let w = NSWindow(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
            w.level = .floating
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.contentView = breakContent(size: size, compact: true)
            w.alphaValue = 0
            w.orderFrontRegardless()
            fadeIn(w)
            overlayWindows.append(w)
        } else {
            for screen in screens {
                let w = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                 backing: .buffered, defer: false)
                w.setFrame(screen.frame, display: false)
                w.level = .screenSaver
                w.isOpaque = false
                w.backgroundColor = .clear
                w.hasShadow = false
                w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                w.contentView = breakContent(size: screen.frame.size, compact: false)
                w.alphaValue = 0
                w.orderFrontRegardless()
                fadeIn(w)
                overlayWindows.append(w)
            }
        }
        updateCountdownLabels()
    }

    private func fadeIn(_ w: NSWindow) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 1
        }
    }

    private func breakContent(size: NSSize, compact: Bool) -> NSView {
        let root = BreakView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: compact ? 0.97 : 0.94).cgColor
        if compact {
            root.layer?.cornerRadius = 16
            root.layer?.masksToBounds = true
            root.layer?.borderWidth = 1
            root.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.12).cgColor
        }
        root.onClick = { [weak self] in self?.finishBreak() }
        root.autoresizingMask = [.width, .height]

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedWhite: 1, alpha: 0.9)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: compact ? 22 : 46, weight: .light)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: Lang.t("Olhe para longe", "Look into the distance"))
        title.font = NSFont.systemFont(ofSize: compact ? 20 : 46, weight: .semibold)
        title.textColor = NSColor(calibratedWhite: 1, alpha: 0.96)
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: Lang.t("Fixe um ponto a cerca de 6 metros (20 pés)",
                                                          "Focus on something about 6 metres (20 feet) away"))
        subtitle.font = NSFont.systemFont(ofSize: compact ? 12 : 19, weight: .regular)
        subtitle.textColor = NSColor(calibratedWhite: 1, alpha: 0.6)
        subtitle.alignment = .center

        let count = NSTextField(labelWithString: "\(Pref.breakSeconds)")
        count.font = NSFont.monospacedDigitSystemFont(ofSize: compact ? 28 : 92, weight: .ultraLight)
        count.textColor = NSColor(calibratedWhite: 1, alpha: 0.95)
        count.alignment = .center

        let hint = NSTextField(labelWithString: compact
                               ? Lang.t("Clique para dispensar", "Click to dismiss")
                               : Lang.t("Clique em qualquer lugar para terminar a pausa",
                                        "Click anywhere to end the break"))
        hint.font = NSFont.systemFont(ofSize: 12)
        hint.textColor = NSColor(calibratedWhite: 1, alpha: 0.38)
        hint.alignment = .center

        let stack = NSStackView(views: [icon, title, subtitle, count, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = compact ? 2 : 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -16)
        ])

        countdownLabels.append(count)
        return root
    }

    @objc func updateCountdownLabels() {
        let s = "\(max(0, Int(ceil(remaining))))"
        for l in countdownLabels { l.stringValue = s }
    }

    func closeOverlay() {
        for w in overlayWindows {
            w.orderOut(nil)
            w.contentView = nil
        }
        overlayWindows.removeAll()
        countdownLabels.removeAll()
    }

    // MARK: Outros

    @objc func about() {
        activateApp()
        let a = NSAlert()
        a.messageText = "Pausa 20-20-20"
        a.informativeText = Lang.t("""
        Regra 20-20-20: a cada 20 minutos de ecrã, olhe durante 20 segundos para algo a cerca de 6 metros (20 pés).

        A app vive apenas na barra de menus e não guarda ficheiros no seu Mac. \
        Pode ajustar os tempos e o idioma no menu do ícone.
        """, """
        The 20-20-20 rule: every 20 minutes of screen time, look at something about 6 metres (20 feet) away for 20 seconds.

        The app lives only in the menu bar and stores no files on your Mac. \
        You can change the timings and language in the icon's menu.
        """)
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    private func activateApp() {
        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
