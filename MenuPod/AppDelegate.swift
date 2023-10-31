//
//  AppDelegate.swift
//  MenuPod
//
//  Created by YUSE Yosihiro on 23/11/01.
//

import Cocoa
// ITL
import iTunesLibrary

struct PlaylistItem {
    let name: String
    let id: Int
}

enum RepeatMode: String {
    case off
    case all
    case one

    mutating func `switch`() {
        switch self {
        case .off: self = .all
        case .all: self = .one
        case .one: self = .off
        }
    }
}

enum MyKey {
    static let showArtwork = "ShowArtWork"
    static let showTitle = "ShowTitle"
    static let recentPid = "RecentPid"
    // TRACKS
    static let recentTracksPid = "RecentTracksPid"
}

enum MySymbol {
    static let play = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
    static let pause = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)
    static let stop = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
    static let back = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
    static let next = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
    static let rewind = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
    static let fastForward = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
    static let listMenu = NSImage(systemSymbolName: "arrowtriangle.down.fill", accessibilityDescription: nil)
    static let replay = NSImage(systemSymbolName: "forward.frame.fill", accessibilityDescription: nil)
    static let volume = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: nil)
    // MUTE
    static let mute = NSImage(systemSymbolName: "speaker.slash.fill", accessibilityDescription: nil)
    static let `repeat` = NSImage(systemSymbolName: "repeat", accessibilityDescription: nil)
    static let repeatOne = NSImage(systemSymbolName: "repeat.1", accessibilityDescription: nil)
    static let shuffle = NSImage(systemSymbolName: "shuffle", accessibilityDescription: nil)
    static let reveal = NSImage(systemSymbolName: "location.north.fill", accessibilityDescription: nil)
}

enum StatusBarButtonType {
    static let normal = 0
    static let multiClick = 1
}

// MARK: - AppDelegate
// - swift - validateMenuItem or menuWillOpen not called for NSMenu - Stack Overflow
// - https://stackoverflow.com/questions/38461449/validatemenuitem-or-menuwillopen-not-called-for-nsmenu
@main
class AppDelegate: NSObject, NSApplicationDelegate/* SEEKBAR */, NSMenuDelegate/* , NSMenuItemValidation */ {
    let myName = "MenuPod"
    //
    // var itm: String {get {if #available(OSX 10.15, *) {return "Music"} else {return "iTunes"}}}
    // var apiVersion: String {get {if #available(OSX 10.15, *) {return "1.1"} else {return "1.0"}}}
    let itm: String = "Music"
    let apiVersion: String = "1.1"
    // ITL
    var useITunesLibrary: Bool = true
    //
    var ud: UserDefaults {get {return UserDefaults.standard}}
    //
    var statusItem: NSStatusItem!
    var statusItem2: NSStatusItem!
    //
    var menu: NSMenu!
    let recentOffset: Int = 2 // 2 for [Control] and [Separator]
    let maxRecent: Int = 20
    var allPlaylistsMenuItem: NSMenuItem!
    var clearRecentMenuItem: NSMenuItem!
    //
    // TRACKS
    var tracksMenuItem: NSMenuItem!
    var recentTracksMenu: NSMenu!
    var allTracksMenu: NSMenu!
    var clearRecentTracksMenuItem: NSMenuItem!
    //
    var title: String = "" {didSet {setButton()}}
    var toolTip: String = "" {didSet {setButton()}}
    var artwork: NSImage? {didSet {setButton()}}
    var symbol: NSImage? {didSet {setButton()}}
    var symbolTimer: Timer?
    // LASTPLAYLIST
    var lastPlaylist: String = "" {didSet {setTitle()}}
    //
    var showTitle: Bool = false {didSet {setTitle()}}
    var showTitleMenuItem: NSMenuItem!
    var showTitleMaxWidth: CGFloat = 185 // 170 // 200
    //
    var showArtwork: Bool = false {didSet {setImage()}}
    var showArtworkMenuItem: NSMenuItem!
    //
    var controlView: NSView!
    var controlItem: NSMenuItem!
    //
    var volumeButton: WheelButton!
    var volume: Int = 100 {didSet {volumeButton.title = String(format: "%3d", volume)}}
    // MUTE
    var mute: Bool = false {didSet {volumeButton.image = mute ? MySymbol.mute : MySymbol.volume}}
    //
    var shuffleButton: NSButton!
    var repeatButton: NSButton!
    var shuffleMode: Bool = false {
        didSet {
            shuffleButton.image?.isTemplate = true
            // shuffleButton.contentTintColor = shuffleMode ? .controlAccentColor : .disabledControlTextColor
            if shuffleMode {shuffleButton.image = shuffleButton.image?.withTintColor(.controlAccentColor)}
        }
    }
    var repeatMode: RepeatMode = .off {
        didSet {
            repeatButton.image = repeatMode == .one ? MySymbol.repeatOne : MySymbol.repeat
            repeatButton.image?.isTemplate = true
            // repeatButton.contentTintColor = repeatMode != .off ? .controlAccentColor : .disabledControlTextColor
            if repeatMode != .off {repeatButton.image = repeatButton.image?.withTintColor(.controlAccentColor)}
        }
    }
    // PLAYBACKCONTROL
    var playPauseButton: NSButton!
    var symbol2: NSImage? {didSet {setButton2()}}
    var timer2: Timer?
    var startTime: Date?
    let delay = NSEvent.doubleClickInterval // 0.5
    var pauseOrStop = MySymbol.pause
    var shouldStop: Bool = false {didSet {
        pauseOrStop = shouldStop ? MySymbol.stop : MySymbol.pause
        if shouldStop {
            setSymbol(pauseOrStop)
            setSymbol2(pauseOrStop)
        } else {updateSymbol()}
    }}
    // SEEKBAR
    var menuIsOpen: Bool = false
    // KNOB
    // var seekbar: NSSlider!
    var seekbar: MySlider!
    var seekbarTimer: Timer?
    // TIMELABEL
    var currentLabel: NSTextField!
    var remainLabel: NSTextField!

    // @IBOutlet var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        guard let button = statusItem.button else {return}
        button.tag = StatusBarButtonType.multiClick
        //
        statusItem2 = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        guard let button2 = statusItem2.button else {return}
        button2.tag = StatusBarButtonType.normal
        //
        showTitle = ud.object(forKey: MyKey.showTitle) as? Bool ?? false
        showArtwork = ud.object(forKey: MyKey.showArtwork) as? Bool ?? false
        //
        menu = NSMenu()
        controlItem = NSMenuItem(title: "Control", action: #selector(showAboutPanel(_:)), keyEquivalent: "") // 何か action を設定しておかないと validateMenuItem(_:) の中で無視されるみたい
        menu.addItem(controlItem)
        makeControlView()
        //
        menu.addItem(.separator())
        menu.addItem(.separator())
        clearRecentMenuItem = NSMenuItem(title: "Clear Recent", action: #selector(clearRecentMenuAndUserDefaults(_:)), keyEquivalent: "")
        menu.addItem(clearRecentMenuItem)
        menu.addItem(.separator())
        allPlaylistsMenuItem = NSMenuItem(title: "All Playlists", action: nil, keyEquivalent: "")
        allPlaylistsMenuItem.submenu = NSMenu()
        menu.addItem(allPlaylistsMenuItem)
        menu.addItem(.separator())
        //
        // TRACKS
        allTracksMenu = NSMenu()
        recentTracksMenu = NSMenu()
        recentTracksMenu.addItem(.separator())
        clearRecentTracksMenuItem = NSMenuItem(title: "Clear Recent", action: #selector(clearRecentTracksMenuAndUserDefaults(_:)), keyEquivalent: "")
        recentTracksMenu.addItem(self.clearRecentTracksMenuItem)
        recentTracksMenu.addItem(.separator())
        let allTracksMenuItem = NSMenuItem(title: "All Songs", action: nil, keyEquivalent: "")
        allTracksMenuItem.submenu = allTracksMenu
        recentTracksMenu.addItem(allTracksMenuItem)
        tracksMenuItem = NSMenuItem(title: "Songs", action: nil, keyEquivalent: "")
        tracksMenuItem.submenu = recentTracksMenu
        menu.addItem(tracksMenuItem)
        menu.addItem(.separator())
        //
        showTitleMenuItem = NSMenuItem(title: "Show Title", action: #selector(toggleTitle(_:)), keyEquivalent: "t")
        menu.addItem(showTitleMenuItem)
        showArtworkMenuItem = NSMenuItem(title: "Show Artwork", action: #selector(toggleArtwork(_:)), keyEquivalent: "a")
        menu.addItem(showArtworkMenuItem)
        menu.addItem(.separator())
        //
        menu.addItem(withTitle: NSLocalizedString("About \(myName)", comment: "About app"), action: #selector(showAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Quit \(myName)", comment: "Quit app"), action: #selector(terminate(_:)), keyEquivalent: "q")
        //
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        // RIGHTCLICK
        statusItem.menu = menu
        //
        statusItem2.button?.imagePosition = .imageLeft
        statusItem2.button?.imageScaling = .scaleProportionallyDown
        statusItem2.menu = menu
        //
        // Dock からアイコンを消す
        NSApp.setActivationPolicy(.accessory)
        //
        // - いま聴いている曲の iTunes Store での trackId を取得する旅 - ちなみに
        // - https://blog.nishimu.land/entry/2016/04/19/090000
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(trackChanged(_:)), name: Notification.Name("com.apple.\(itm).playerInfo"), object: nil)
        //
        updateSymbol()
        setImage()
        setTitle()
        // SEEKBAR
        menu.delegate = self
        //
        asyncSetupPlaylistsMenuAndRecentMenuItem()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // SEEKBAR
    func menuWillOpen(_ menu: NSMenu) {
        // startSeekbar()
        if do_player_state_as_text() == "playing" {startSeekbar()}
        else {updateSeekbar()}
        menuIsOpen = true
    }

    // SEEKBAR
    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        stopSeekbar()
    }

    func makeControlView() {
        controlView = NSView(frame: NSRect(x: 0, y: 0, width: 170, height: 22))
        let systemFont = NSFont.systemFont(ofSize: 13)

        func makeMyButton<T: NSButton>(font: NSFont? = systemFont, symbol: NSImage?, title: String = "", x: Int, y: Int, width: Int, height: Int, alignment: NSTextAlignment = .natural, imagePosigion: NSControl.ImagePosition = .imageOnly, selector: Selector?) -> T {
            let button: T = T(frame: NSRect(x: x, y: y, width: width, height: height))
            button.action = selector
            button.alignment = alignment
            button.bezelStyle = .inline
            button.focusRingType = .none
            button.font = font
            button.image = symbol
            button.image?.isTemplate = true
            button.imagePosition = imagePosigion
            button.isBordered = false
            button.target = self
            button.title = title
            return button
        }

        // TIMELABEL
        func makeLabel(x: Int, y: Int, width: Int, height: Int, alignment: NSTextAlignment) -> NSTextField {
            let label: NSTextField = NSTextField(frame: NSRect(x: x, y: y, width: width, height: height))
            label.alignment = alignment
            label.drawsBackground = false
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            label.isBezeled = false
            label.isEditable = false
            label.textColor = .disabledControlTextColor
            // label.stringValue = "0:00"
            return label
        }

        let offset = 20
        let padding = 4
        var width = 20 + padding * 2
        var height = 20
        var x = offset
        var y = 0
        shuffleButton = makeMyButton(symbol: MySymbol.shuffle, x: x, y: y, width: width, height: height, selector: #selector(shuffleAction(_:)))
        x += width + padding
        repeatButton = makeMyButton(symbol: MySymbol.repeat, x: x, y: y, width: width, height: height, selector: #selector(repeatAction(_:)))
        controlView.addSubview(shuffleButton)
        controlView.addSubview(repeatButton)
        x += width + padding

        let monospacedDigitSystemFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        volumeButton = makeMyButton(font: monospacedDigitSystemFont, symbol: MySymbol.volume, title: "100", x: x, y: y, width: 41, height: 20, alignment: .right, imagePosigion: .imageRight, selector: /* MUTE */ /* nil */ #selector(muteAction(_:)))
        controlView.addSubview(volumeButton)
        // REVEAL
        x += 41 + padding
        width = 13 + padding * 2
        let revealButton: NSButton = makeMyButton(symbol: MySymbol.reveal, x: x, y: y, width: width, height: height, selector: #selector(revealAction(_:)))
        controlView.addSubview(revealButton)
        x += width
        x += offset
        y += 22
        controlView.setFrameSize(NSSize(width: x, height: y))
        // PLAYBACKCONTROL
        let x0 = x
        x = offset
        width = 24 + padding * 2
        let backTrackButton: NSButton = makeMyButton(symbol: MySymbol.back, x: x, y: y, width: width, height: height, selector: #selector(backTrackOrRewindAction(_:)))
        backTrackButton.sendAction(on: [.leftMouseUp, .leftMouseDown])
        x += width + padding
        width = 28 + padding * 2
        playPauseButton = makeMyButton(symbol: MySymbol.play, x: x, y: y, width: width, height: height, selector: #selector(playPauseOrStopAction(_:)))
        playPauseButton.sendAction(on: [.leftMouseUp, .leftMouseDown, .leftMouseDragged])
        x += width + padding
        width = 24 + padding * 2
        let nextTrackButton = makeMyButton(symbol: MySymbol.next, x: x, y: y, width: width, height: height, selector: #selector(nextTrackOrFastForwardAction(_:)))
        nextTrackButton.sendAction(on: [.leftMouseUp, .leftMouseDown])
        x += width + padding
        controlView.addSubview(backTrackButton)
        controlView.addSubview(playPauseButton)
        controlView.addSubview(nextTrackButton)
        y += 22
        controlView.setFrameSize(NSSize(width: x0, height: y))
        // SEEKBAR
        x = offset
        width = 24 + padding * 2
        width += padding
        width += 28 + padding * 2
        width += padding
        width += 24 + padding * 2
        height = 16
        // KNOB
        // seekbar = NSSlider(frame: NSRect(x: x, y: y, width: width, height: height))
        seekbar = MySlider(frame: NSRect(x: x, y: y, width: width, height: height))
        seekbar.cell = MySliderCell()
        seekbar.cell?.action = #selector(seekAction(_:))
        seekbar.controlSize = .mini
        seekbar.sliderType = .linear
        seekbar.minValue = 0
        seekbar.maxValue = 1
        seekbar.doubleValue = 0
        // KNOB
        seekbar.focusRingType = .none
        controlView.addSubview(seekbar)
        y += height
        controlView.setFrameSize(NSSize(width: x0, height: y))
        // TIMELABEL
        x = offset
        let width0 = width
        width = width0 / 2
        height = 16
        currentLabel = makeLabel(x: x, y: y, width: width, height: height, alignment: .left)
        x += width0 - width
        remainLabel = makeLabel(x: x, y: y, width: width, height: height, alignment: .right)
        controlView.addSubview(currentLabel)
        controlView.addSubview(remainLabel)
        y += 20
        controlView.setFrameSize(NSSize(width: x0, height: y))
        //
        controlItem.view = controlView
        controlView.layoutSubtreeIfNeeded() // よく分からないがこれを書いておくとちらつかない
    }

    @objc func refreshPlaylists(_ sender: Any) {
        allPlaylistsMenuItem.submenu?.removeAllItems()
        asyncSetupPlaylistsMenuAndRecentMenuItem()
    }

    @objc func clearRecentMenuAndUserDefaults(_ sender: Any) {
        clearRecentMenu()
        writeRecentMenuToUserDefaults()
    }

    // TRACKS
    @objc func refreshTracksMenu(_ sender: Any) {
        allTracksMenu.removeAllItems()
        asyncSetupPlaylistsMenuAndRecentMenuItem()
    }

    // TRACKS
    @objc func clearRecentTracksMenuAndUserDefaults(_ sender: Any) {
        clearRecentTracksMenu()
        writeRecentTracksMenuToUserDefaults()
    }

    // SEEKBAR
    @objc func seekAction(_ sender: AnyObject) {
        let pos = seekbar.doubleValue
        let scpt = """
        tell application \(itm.quoted)
            try
                set player position to \(pos) * (duration of current track)
            on error
                ""
            end try
        end tell
        """
        let _ = doAppleScript(script: scpt)
    }

    // SEEKBAR
    func updateSeekbar() {
        // TIMELABEL
        /*
        let scpt = """
        tell application \(itm.quoted)
            try
                player position / (duration of current track)
            on error
                0
            end try
        end tell
        """
        let s: String = doAppleScript(script: scpt)
        seekbar.doubleValue = Double(s) ?? 0
         */
        //
        func stringOf(_ time: TimeInterval, prefix: String = "") -> String {
            let min = Int(time) / 60 // Int(round(time)) / 60
            let sec = Int(time) % 60 // Int(round(time)) % 60
            return String(format: "%@%d:%02d", prefix, min, sec)
        }
        let s: String = doAppleScript(script: """
        tell application \(itm.quoted)
            try
                "" & player position & "\t" & duration of current track
            on error
                "0\t0"
            end try
        end tell
        """)
        let ary = s.components(separatedBy: "\t")
        guard ary.count == 2 else {return}
        let duration = Double(ary[1]) ?? 0
        let current = Double(ary[0]) ?? 0
        let remain = duration - current
        currentLabel.stringValue = stringOf(current)
        remainLabel.stringValue = stringOf(remain, prefix: "-")
        seekbar.doubleValue = duration == 0 ? 0 :  current / duration
    }

    // SEEKBAR
    func startSeekbar() {
        updateSeekbar()
        seekbarTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: {timer in self.updateSeekbar()})
        RunLoop.main.add(seekbarTimer!, forMode: .common)
    }

    // SEEKBAR
    func stopSeekbar() {
        seekbarTimer?.invalidate()
        updateSeekbar()
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem {
        case controlItem:
            get_player_settings()
            // PLAYBACKCONTROL
            updateSymbol()
        case showTitleMenuItem: menuItem.state = showTitle ? .on : .off
        case showArtworkMenuItem: menuItem.state = showArtwork ? .on : .off
        case clearRecentMenuItem: return recentItem.count != 0
            // TRACKS
        case clearRecentTracksMenuItem: return recentTracksItem.count != 0
        default: break
        }
        return true
    }

    @objc func trackChanged(_ notification: Notification) {
        // SEEKBAR
        if menuIsOpen {stopSeekbar()}
        if let userInfo: Dictionary = notification.userInfo {
            let playerState = userInfo["Player State"] as? String
            let title = userInfo["Name"] as? String
            switch playerState {
            case "Playing":
                setSymbol(MySymbol.pause)
                setSymbol2(MySymbol.pause)
                // SEEKBAR
                if menuIsOpen {startSeekbar()}
            case "Stopped":
                setSymbol(MySymbol.replay)
                setSymbol2(MySymbol.replay)
            default:
                setSymbol(MySymbol.play)
                setSymbol2(MySymbol.play)
            }
            setImage()
            setTitle(title: title)
        }
        doGlobalRecent()
    }

    // GLOBALRECENT
    func doGlobalRecent() {
        // iTunes や他のアプリから再生したプレイリストも記録
        let pid = do_persistent_ID_of_current_playlist()
        if !pid.isEmpty, let name = pidToName[pid], let id = pidToId[pid] {
            // すでに記録していれば何もしない
            if let menuItem = menu.item(at: recentOffset + 0), menuItem.title == name && menuItem.tag == id {return}
            // 記録
            updateRecentMenuItem(name: name, id: id)
        }
        // LASTPLAYLIST
        if let menuItem = menu.item(at: recentOffset + 0) {lastPlaylist = menuItem.title}
    }

    // XXX: ネーミング: get_player_state() か
    func updateSymbol() {
        let state = do_player_state_as_text()
        switch state {
        case "playing": setSymbol(MySymbol.pause)
        case "stopped": setSymbol(MySymbol.replay)
        default: setSymbol(MySymbol.play)
        }
        // PLAYBACKCONTROL
        switch state {
        case "playing", "fast forwarding", "rewinding": setSymbol2(pauseOrStop)
        case "stopped": setSymbol2(MySymbol.replay)
        case "paused", _: setSymbol2(MySymbol.play)
        }
    }

    func setSymbolAWhile(_ image: NSImage?) {
        symbolTimer?.invalidate()
        symbolTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.doubleClickInterval, repeats: false, block: {(timer) -> Void in
            self.updateSymbol()
        })
        RunLoop.main.add(symbolTimer!, forMode: .common)
        symbol = image
    }

    func setSymbol(_ image: NSImage?) {
        symbol = image
    }

    func setSymbol2(_ image: NSImage?) {
        symbol2 = image
    }

    @objc func playPauseAction(_ sender: Any) {
        // 停止中以外 (再生中/一時停止中/…) なら playpause, 停止中なら一番最近の項目を再生
        if do_player_state_as_text() != "stopped" {let _ = do_playpause()}
        else {if let menuItem = menu.item(at: recentOffset + 0) {menuItemSelected(menuItem, autoShuffle: true)}}
    }

    @objc func nextTrackAction(_ sender: Any) {
        setSymbolAWhile(MySymbol.next)
        let _ = do_next_track()
    }

    @objc func backTrackAction(_ sender: Any) {
        setSymbolAWhile(MySymbol.back)
        let _ = do_back_track()
    }

    @objc func longPressBeganAction(_ sender: Any) {
        guard let event = NSApp.currentEvent else {return}
        switch event.clickCount {
        case 1:
            // LONGPRESSTOMENU
            // // LONGPRESSTOSTOPORMENU
            // if symbol == MySymbol.replay {setSymbol(MySymbol.listMenu)}
            // else {setSymbol(MySymbol.stop)}
            setSymbol(MySymbol.listMenu)
        case 2:
            setSymbol(MySymbol.fastForward)
            let _ = do_fast_forward()
        case 3:
            setSymbol(MySymbol.rewind)
            let _ = do_rewind()
        default: break
        }
    }

    @objc func longPressEndedAction(_ sender: Any) {
        guard let event = NSApp.currentEvent else {return}
        switch event.clickCount {
        case 1:
            // LONGPRESSTOMENU
            // LONGPRESSTOSTOPORMENU
            // if symbol == MySymbol.stop {let _ = do_stop()}
            // else {doPopUpMenu()}
            doPopUpMenu()
        case 2, 3, 0: let _ = do_resume()
        default: break
        }
        updateSymbol()
    }

    @objc func stopAction(_ sender: Any) {
        let _ = do_stop()
    }

    @objc func playPauseOrStopAction(_ sender: Any) {
        guard let event = NSApp.currentEvent else {return}
        switch event.type {
        case .leftMouseDown:
            timer2?.invalidate()
            startTime = Date()
            let stopDelay: TimeInterval = delay * 2 // 2.0 // XXX
            timer2 = Timer.scheduledTimer(withTimeInterval: stopDelay, repeats: false, block: {(timer) -> Void in
                self.shouldStop = true
            })
            RunLoop.main.add(timer2!, forMode: .common)
        case .leftMouseUp:
            timer2?.invalidate()
            if shouldStop {stopAction(sender)}
            else {playPauseAction(sender)}
            shouldStop = false
        default:
            timer2?.invalidate()
            shouldStop = false
        }
    }

    @objc func backTrackOrRewindAction(_ sender: AnyObject) {
        guard let event = NSApp.currentEvent else {return}
        switch event.type {
        case .leftMouseDown:
            timer2?.invalidate()
            startTime = Date()
            timer2 = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: {(timer) -> Void in let _ = self.do_rewind()})
            RunLoop.main.add(timer2!, forMode: .common)
        case .leftMouseUp, _:
            timer2?.invalidate()
            let span: TimeInterval = Date().timeIntervalSince(startTime!)
            if span < delay {let _ = do_back_track()}
            else {let _ = do_resume()}
        }
    }

    @objc func nextTrackOrFastForwardAction(_ sender: AnyObject) {
        guard let event = NSApp.currentEvent else {return}
        switch event.type {
        case .leftMouseDown:
            timer2?.invalidate()
            startTime = Date()
            timer2 = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: {(timer) -> Void in let _ = self.do_fast_forward()})
            RunLoop.main.add(timer2!, forMode: .common)
        case .leftMouseUp, _:
            timer2?.invalidate()
            let span: TimeInterval = Date().timeIntervalSince(startTime!)
            if span < delay {let _ = do_next_track()}
            else {let _ = do_resume()}
        }
    }

    func doPopUpMenu() {
        // - Mac ステータスバーアプリの右クリックと左クリックの分け方
        // - https://zenn.dev/coffmark/articles/bcb5ebf2d5325f2863e1
        // - cocoa - What is alternative to NSStatusItem.popUpMenu? - Stack Overflow
        // - https://stackoverflow.com/questions/52585275/what-is-alternative-to-nsstatusitem-popupmenu
        // statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // statusItem.menu = nil
        // statusItem.menu = menu
    }

    @objc func volumeUpAction(_ sender: Any) {
        do_sound_volume_relative(10)
    }

    @objc func volumeDownAction(_ sender: Any) {
        do_sound_volume_relative(-10)
    }

    // MUTE
    @objc func muteAction(_ sender: Any) {
        do_set_mute()
    }

    @objc func shuffleAction(_ sender: Any) {
        do_shuffle_enabled()
    }

    @objc func repeatAction(_ sender: Any) {
        do_song_repeat()
    }

    @objc func revealAction(_ sender: Any) {
        let _ = do_reveal_current_track()
    }

    @objc func showAboutPanel(_ sender: Any) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @objc func terminate(_ sender: Any) {
        NSApp.terminate(self)
    }

    @objc func toggleTitle(_ sender: Any) {
        showTitle.toggle()
        ud.set(showTitle, forKey: MyKey.showTitle)
        ud.synchronize()
    }

    @objc func toggleArtwork(_ sender: Any) {
        showArtwork.toggle()
        ud.set(showArtwork, forKey: MyKey.showArtwork)
        ud.synchronize()
    }

    // MARK: iTunesCtrl
    func doAppleScript(script: String) -> String {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            // print([output.stringValue, error])
            return output.stringValue ?? ""
        }
        return ""
    }

    func do_reveal_current_track() -> String {
        let scpt = """
        tell application \(itm.quoted)
            try
                activate
                reveal current track
            on error
                ""
            end try
            ""
        end tell
        """
        return doAppleScript(script: scpt)
    }

    func do_play_playlist(pid: String, shuffle: Bool = false) -> String {
        let s = shuffle ? "true" : "false"
        let scpt = """
        tell application \(itm.quoted)
            set shuffle enabled to \(s)
            set pls to every playlist whose persistent ID is \(pid.quoted)
            if count of pls is 1 then
                set pl to item 1 of pls
                play pl
                name of pl
            else
                ""
            end if
        end tell
        """
        return doAppleScript(script: scpt)
    }

    func do_playlists() -> String {
        let scpt = """
        tell application \(itm.quoted)
            set s to ""
            set n to count playlist
            repeat with i from 1 to n
                tell playlist i
                    try
                        set parentId to id of parent
                    on error
                        set parentId to ""
                    end try
                    set s to s & special kind & "\t" &  (count track) & "\t" & parentId & "\t" & name & "\t" & id & "\t" & persistent ID & "\t" & duration
                    set s to s & return
                end tell
            end repeat
            s
        end tell
        """
        return doAppleScript(script: scpt)
    }

    func do_playpause() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to playpause")
    }

    func do_stop() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to stop")
    }

    func do_next_track() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to next track")
    }

    func do_back_track() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to back track")
    }

    func do_fast_forward() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to fast forward")
    }

    func do_rewind() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to rewind")
    }

    func do_resume() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to resume")
    }

    func do_player_state_as_text() -> String {
        return doAppleScript(script: "tell application \(itm.quoted) to player state as text")
    }

    func do_sound_volume_relative(_ delta: Int, roundToMultiple: Bool = true) {
        var vol: String = doAppleScript(script: "tell application \(itm.quoted) to sound volume as number")
        guard let v = Float(vol) else {return}
        if roundToMultiple {
            // delta の倍数に丸める
            let d = Float(abs(delta))
            let volume = Int(delta < 0 ? floor(v / d) : ceil(v / d)) * Int(d)
            vol = vol != String(volume) ? String(volume) : String(volume + delta)
        } else {vol = String(Int(v) + delta)}

        let scpt = """
        tell application \(itm.quoted)
            set sound volume to \(vol)
            sound volume as number
        end tell
        """
        vol = doAppleScript(script: scpt)
        //
        if let v = Int(vol) {volume = v}
    }

    // MUTE
    func do_set_mute() {
        let scpt = """
        tell application \(itm.quoted)
            set mute to not mute
            mute
        end tell
        """
        let s = doAppleScript(script: scpt)
        mute = s == "true"
    }

    func do_shuffle_enabled() {
        shuffleMode.toggle()
        let s = shuffleMode ? "true" : "false"
        let scpt = "tell application \(itm.quoted) to set shuffle enabled to \(s)"
        let _ = doAppleScript(script: scpt)
    }

    func do_song_repeat() {
        repeatMode.switch()
        let s: String = repeatMode.rawValue
        let scpt = "tell application \(itm.quoted) to set song repeat to \(s)"
        let _ = doAppleScript(script: scpt)
    }

    func get_player_settings() {
        let scpt = """
        tell application \(itm.quoted)
            set s to ""
            set s to s & shuffle enabled & return
            set s to s & song repeat & return
            -- // MUTE
            -- set s to s & sound volume
            set s to s & sound volume & return
            set s to s & mute
            --- // /MUTE
            s
        end tell
        """
        let s = doAppleScript(script: scpt)
        let a = s.components(separatedBy: "\r")
        // MUTE
        // if a.count != 3 {return}
        // let (sh, re, vol) = (a[0], a[1], a[2])
        if a.count != 4 {return}
        let (sh, re, vol, mu) = (a[0], a[1], a[2], a[3])
        //
        if let v = Int(vol) {volume = v}
        shuffleMode = sh == "true" ? true : false
        repeatMode = re == "all" ? .all : re == "one" ? .one : .off
        // MUTE
        mute = mu == "true"
    }

    // GLOBALRECENT
    func do_persistent_ID_of_current_playlist() -> String {
        let scpt = """
        tell application \(itm.quoted)
            try
                persistent ID of current playlist
            on error
                ""
            end try
        end tell
        """
        return doAppleScript(script: scpt)
    }

    // MARK: Playlists menu item
    // 各種テーブル
    // pid は persistent ID (process ID とか parentID とかでなく)
    var idToMenuItem: [Int:NSMenuItem] = [:]
    var idToPid: [Int:String] = [:]
    var pidToName: [String:String] = [:]
    var pidToId: [String:Int] = [:]
    var pidToToolTip: [String:String] = [:]
    // TRACKS
    var pidToDiscNo: [String:Int] = [:]
    var pidToTrackNo: [String:Int] = [:]

    func asyncSetupPlaylistsMenuAndRecentMenuItem() {
        // TRACKS
        allPlaylistsMenuItem.submenu?.removeAllItems()
        allTracksMenu.removeAllItems()
        // recentItem とメニューをクリア
        clearRecentMenu()
        // TRACKS
        clearRecentTracksMenu()
        // // ダミーの項目を入れておく
        // menu.insertItem(NSMenuItem(title: "Loading…", action: nil, keyEquivalent: ""), at: recentOffset + 0)
        // // TRACKS
        // allTracksMenu.insertItem(NSMenuItem(title: "Loading…", action: nil, keyEquivalent: ""), at:0)
        //
        DispatchQueue.global().async {
            let list = self.getPlaylists()
            DispatchQueue.main.async {
                self.setupAllPlaylistsMenu(list: list)
                //
                self.allPlaylistsMenuItem.submenu?.addItem(.separator())
                self.allPlaylistsMenuItem.submenu?.addItem(withTitle: "Refresh List", action: #selector(self.refreshPlaylists(_:)), keyEquivalent: "")
                // // ダミーの項目を取り除く
                // self.menu.removeItem(at: self.recentOffset + 0)
                self.setupRecentMenuItem()
            }
            // TRACKS
            let trackList = self.getTracks()
            DispatchQueue.main.async {
                self.setupAllTracksMenu(list: trackList)
                //
                self.allTracksMenu.addItem(NSMenuItem.separator())
                self.allTracksMenu.addItem(NSMenuItem(title: "Refresh List", action: #selector(self.refreshTracksMenu(_:)), keyEquivalent: ""))
                // // ダミーの項目を取り除く
                // self.allTracksMenu.removeItem(at: 0)
                self.setupRecentTracksMenu()
            }
        }
    }

    func getPlaylists() -> String {
        // テーブルを初期化
        idToMenuItem = [:]
        idToPid = [:]
        pidToName = [:]
        pidToId = [:]
        pidToToolTip = [:]
        // TRACKS
        pidToDiscNo = [:]
        pidToTrackNo = [:]

        // ITL
        if useITunesLibrary {return ""}

        // プレイリストの名前, id, pid などを取得
        let list = do_playlists()

        return list
    }

    // ITL
    func setupAllPlaylistsMenuFromITunesLibrary() {
        // - itunes - Is the format/schema of the Apple Music “Library.musicdb” used in macOS Catalina documented anywhere? - Super User
        // - https://superuser.com/questions/1491509/is-the-format-schema-of-the-apple-music-library-musicdb-used-in-macos-catalina
        // > API version 1.1 seems to be for Music.app, whilst 1.0 should be for iTunes.
        guard let library = try? ITLibrary(apiVersion: apiVersion) else {return}
        var playlists = library.allPlaylists
        playlists = playlists.sorted(by: {(lhs, rhs) -> Bool in
            func path(_ playlist: ITLibPlaylist) -> String {
                var path: [String] = [playlist.name]
                var pl = playlist
                while true {
                    if pl.parentID != nil, let parent = playlists.first(where: {$0.persistentID == pl.parentID}) {
                        path.append(parent.name)
                        pl = parent
                    } else {break}
                }
                return path.reversed().joined(separator: "\t") // XXX: "\t"
            }

            if lhs.kind == .folder && rhs.kind != .folder {return true}
            if lhs.kind != .folder && rhs.kind == .folder {return false}
            return path(lhs).localizedStandardCompare(path(rhs)) == .orderedAscending
        })
        for p in playlists {
            var kind: String
            switch p.kind {
            case .folder: kind = "folder"
            case .genius: kind = "Genius"
            case .geniusMix: kind = "GeniusMix"
            case .regular: kind = "none"
            case .smart: kind = "smart"
            @unknown default: kind = "unknown"
            }
            // SONGITEMS/
            let songItems = p.items.filter({$0.mediaKind == .kindSong})
            // SONGITEMS/
            let count = songItems.count // p.items.count
            let parentId = p.parentID?.hex() ?? ""
            let name = p.name
            let id = Int(truncating: p.persistentID) // XXX: is it OK?
            let pid = p.persistentID.hex()
            // SONGITEMS/
            let duration = Int(songItems.map({$0.totalTime}).reduce(0) {$0 + $1} / 1000) // Int(p.items.map({$0.totalTime}).reduce(0) {$0 + $1} / 1000)
            // 除外するもの
            // SONGITEMS/
            if count == 0 {continue} // XXX
            if kind == "none" && parentId == "" && name == "ライブラリ" {continue}
            switch p.distinguishedKind {
            case .kindPodcasts, .kindAudiobooks, .kindTVShows, .kindMusicShowsAndMovies, .kindHomeVideos, .kindMusic, .kindMusicVideos, .kindLibraryMusicVideos, .kindMovies: continue
            default: break
            }
            //
            addToAllPlaylistsMenu(kind: kind, count: count, parentId: parentId, name: name, id: id, pid: pid, duration: duration)
            // print([p.distinguishedKind.rawValue, kind, count, parentId, name, id, pid, duration])
        }
    }

    func setupAllPlaylistsMenu(list: String) {
        // ITL
        if useITunesLibrary {
            setupAllPlaylistsMenuFromITunesLibrary()
            return
        }
        //
        for line in list.components(separatedBy: "\r") {
            let ary = line.components(separatedBy: "\t")
            if ary.count == 7 {
                let kind = ary[0]
                let count = Int(ary[1]) ?? 0
                let parentId = ary[2]
                let name = ary[3]
                let id = Int(ary[4]) ?? 0 // XXX: 0
                let pid = ary[5]
                let duration = Int(ary[6]) ?? 0
                // ITL
                // XXX: "ホームビデオ" を除外
                if kind == "none" && parentId == "" && name == "ホームビデオ" {continue}
                // XXX: "none", "folder", "Genius", "Purchased Music" 以外を除外
                switch kind {
                case "none", "folder", "Genius", "Purchased Music":
                    break
                case "Books", "iTunes U", "Library", "Movies", "Music", "Podcasts", "TV Shows", _:
                    continue
                }
                //
                addToAllPlaylistsMenu(kind: kind, count: count, parentId: parentId, name: name, id: id, pid: pid, duration: duration)
            }
        }
    }

    func addToAllPlaylistsMenu(kind: String, count: Int, parentId: String, name: String, id: Int, pid: String, duration: Int) {
        // テーブルに追加
        idToPid[id] = pid
        pidToName[pid] = name
        pidToId[pid] = id

        // メニュー項目を作成
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.title = name
        menuItem.tag = id
        // フォルダならサブメニューを、プレイリストならセレクタを設定
        switch kind {
        case "folder":
            menuItem.submenu = NSMenu()
        case "none", _:
            menuItem.action = count == 0 ? nil : #selector(AppDelegate.menuItemSelected(_:))
            // ツールチップ
            let toolTip = "\(count) songs, \(Int(ceil(Float(duration) / 60.0))) min"
            menuItem.toolTip = toolTip
            pidToToolTip[pid] = toolTip
        }
        // テーブルに追加
        idToMenuItem[id] = menuItem

        // 親フォルダがなければトップレベルに、親フォルダがあればそこにメニューを配置
        if parentId == "" {
            allPlaylistsMenuItem.submenu?.addItem(menuItem)
        } else {
            // ITL
            if useITunesLibrary {
                if let parentId = pidToId[parentId] {
                    idToMenuItem[parentId]?.submenu?.addItem(menuItem)
                }
            }
            else
            //
            if let parentId = Int(parentId) {
                idToMenuItem[parentId]?.submenu?.addItem(menuItem)
            }
        }
    }

    @objc func menuItemSelected(_ sender: AnyObject) {
        menuItemSelected(sender, autoShuffle: false)
    }

    func menuItemSelected(_ sender: AnyObject, autoShuffle: Bool) {
        // メニュー項目から id, pid を取得
        guard let id:Int = sender.tag else {return}
        guard let pid: String = idToPid[id] else {return}
        // AUTOSHUFFLE
        let controlKey: NSEvent.ModifierFlags = .control
        let currentShuffle = doAppleScript(script: "tell application \(itm.quoted) to shuffle enabled") == "true"
        guard let event = NSApp.currentEvent else {return}
        let shuffle: Bool = autoShuffle ? currentShuffle : NSEvent.modifierFlags.contains(controlKey) || event.type == .rightMouseUp || event.type == .otherMouseUp
        //
        // 指定されたプレイリストを再生しプレイリスト名を取得
        // AUTOSHUFFLE
        let name: String = do_play_playlist(pid: pid, shuffle: shuffle)
        //
        // 再生と名前の取得に成功すればメニューを更新
        if !name.isEmpty {
            updateRecentMenuItem(name: name, id: id)
        }
        // 名前の取得に失敗して name == "" のときやプレイリストの名前が変更されていたとき
        if name != sender.title {
            // もとの名前の方は削除する
            removeFromRecentMenuItem(name: sender.title, id: id)
            // XXX: アラートを出すなどした方がいいか?
        }
    }

    // MARK: Recent menu item
    var recentItem: [PlaylistItem] = []
    var recentMenuItemCount = 0

    func updateRecentMenuItem(name: String, id: Int) {
        // メニュー項目を作成
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.title = name
        menuItem.tag = id
        menuItem.action = #selector(AppDelegate.menuItemSelected(_:))
        if let pid = idToPid[id] {
            menuItem.toolTip = pidToToolTip[pid]
        }

        // 重複を避けるため name, id に合致する項目を recentItem とメニューから削除
        for i in (0..<recentItem.count).reversed() {
            if recentItem[i].name == name && recentItem[i].id == id {
                recentItem.remove(at: i)
                if i < recentMenuItemCount {
                    menu.removeItem(at: recentOffset + i)
                    recentMenuItemCount -= 1
                }
            }
        }
        // recentItem とメニューの先頭に追加
        recentItem.insert(PlaylistItem(name: name, id: id), at: 0)
        menu.insertItem(menuItem, at: recentOffset + 0)
        recentMenuItemCount += 1

        // 最大で maxRecent 個の項目だけ残す
        if maxRecent < recentMenuItemCount {
            for _ in maxRecent..<recentMenuItemCount {
                menu.removeItem(at: recentOffset + maxRecent)
                recentMenuItemCount -= 1
            }
        }

        // userDefaults に書き出し
        writeRecentMenuToUserDefaults()
    }

    func clearRecentMenu() {
        // recentItem と メニューを空にする
        recentItem = []
        for _ in 0..<recentMenuItemCount {
            menu.removeItem(at: recentOffset + 0)
            recentMenuItemCount -= 1
        }
    }

    func setupRecentMenuItem() {
        // userDefaults から読み出し
        guard let recentPid: [String] = ud.object(forKey: MyKey.recentPid) as? [String] else {return}
        // recentPid から recentItem を設定
        for i in (0..<recentPid.count).reversed() {
            let pid = recentPid[i]
            if let name = pidToName[pid], let id = pidToId[pid] {
                recentItem.insert(PlaylistItem(name: name, id: id), at: 0)
            }
        }
        // recentItem からメニューを設定
        let max = [maxRecent, recentItem.count].min()!
        for i in (0..<max).reversed() {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = recentItem[i].name
            menuItem.tag = recentItem[i].id
            menuItem.action = #selector(AppDelegate.menuItemSelected(_:))
            if let pid = idToPid[recentItem[i].id] {
                menuItem.toolTip = pidToToolTip[pid]
            }
            menu.insertItem(menuItem, at: recentOffset + 0)
            recentMenuItemCount += 1
        }
        // GLOBALRECENT
        doGlobalRecent()
    }

    func removeFromRecentMenuItem(name: String, id: Int) {
        for i in (0..<recentItem.count).reversed() {
            // name, id に合致する項目を recentItem とメニューから削除
            if recentItem[i].name == name && recentItem[i].id == id {
                recentItem.remove(at: i)
                if i < recentMenuItemCount {
                    menu.removeItem(at: recentOffset + i)
                    recentMenuItemCount -= 1
                }
            }
        }
        // 補欠
        let max = [maxRecent, recentItem.count].min()!
        for i in (recentMenuItemCount..<max).reversed() {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = recentItem[i].name
            menuItem.tag = recentItem[i].id
            menuItem.action = #selector(AppDelegate.menuItemSelected(_:))
            if let pid = idToPid[recentItem[i].id] {
                menuItem.toolTip = pidToToolTip[pid]
            }
            menu.insertItem(menuItem, at: recentOffset + i)
            recentMenuItemCount += 1
        }
        // userDefaults に書き出し
        writeRecentMenuToUserDefaults()
    }

    func writeRecentMenuToUserDefaults() {
        // userDefaults に書き出し
        ud.set(recentItem.filter {idToPid[$0.id] != nil}.map {idToPid[$0.id]!}, forKey: MyKey.recentPid)
        ud.synchronize()
    }

    // TRACKS
    // MARK: tracks menu
    func do_tracks() -> String {
        let scpt = """
        tell application \(itm.quoted)
            set s to ""
            set n to count tracks
            repeat with i from 1 to n
                tell track i
                    set s to s & compilation & "\t" & artist & "\t" & album & "\t" & name & "\t" & id & "\t" & persistent ID & "\t" & duration & "\t" & disc number & "\t" & track number & return
                end tell
            end repeat
            s
        end tell
        """
        return doAppleScript(script: scpt)
    }

    func getTracks() -> String {
        // ITL
        if useITunesLibrary {return ""}
        return do_tracks()
    }

    // ITL
    func setupAllTracksMenuFromITunesLibrary() {
        // - itunes - Is the format/schema of the Apple Music “Library.musicdb” used in macOS Catalina documented anywhere? - Super User
        // - https://superuser.com/questions/1491509/is-the-format-schema-of-the-apple-music-library-musicdb-used-in-macos-catalina
        // > API version 1.1 seems to be for Music.app, whilst 1.0 should be for iTunes.
        guard let library = try? ITLibrary(apiVersion: apiVersion) else {return}
        let tracks = library.allMediaItems.sorted()
        for t in tracks {
            let mediaKind = t.mediaKind
            let compilation = t.album.isCompilation
            let artist = t.artist?.name ?? "Unknown Artist"
            let album = t.album.title ?? "Unknown Album"
            let name = t.title
            let id = Int(truncating: t.persistentID) // XXX: is it OK?
            let pid = t.persistentID.hex()
            let duration = Double(t.totalTime) / 1000
            let discNo = t.album.discNumber
            let trackNo = t.trackNumber
            if mediaKind == .kindSong {
                addToAllTracksMenu(compilation: compilation, artist: artist, album: album, name: name, id: id, pid: pid, duration: duration, discNo: discNo, trackNo: trackNo)
            }
        }
    }

    func setupAllTracksMenu(list: String) {
        // ITL
        if useITunesLibrary {
            setupAllTracksMenuFromITunesLibrary()
            return
        }
        //
        for line in list.components(separatedBy: "\r") {
            let ary = line.components(separatedBy: "\t")
            if ary.count == 9 {
                let compilation = ary[0] == "true"
                let artist = ary[1]
                let album = ary[2]
                let name = ary[3]
                let id = Int(ary[4]) ?? 0
                let pid = ary[5]
                let duration = Double(ary[6]) ?? 0
                let discNo = Int(ary[7]) ?? 0
                let trackNo = Int(ary[8]) ?? 0
                addToAllTracksMenu(compilation: compilation, artist: artist, album: album, name: name, id: id, pid: pid, duration: duration, discNo: discNo, trackNo: trackNo)
            }
        }
    }

    func addToAllTracksMenu(compilation: Bool, artist: String, album: String, name: String, id: Int, pid: String, duration: Double, discNo: Int, trackNo: Int) {
        //
        idToPid[id] = pid
        pidToName[pid] = name
        pidToId[pid] = id
        pidToDiscNo[pid] = discNo
        pidToTrackNo[pid] = trackNo
        //
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.title = name
        menuItem.tag = id
        menuItem.target = self
        menuItem.action = #selector(trackMenuItemSelected(_:))
        //
        // ツールチップ
        let min = Int(ceil(duration / 60.0))
        let toolTip = "\(min) min"
        menuItem.toolTip = toolTip
        pidToToolTip[pid] = toolTip
        //
        let artistOrCompilation = compilation ? "Compilations" : artist
        var artistMenuItem: NSMenuItem? = allTracksMenu.item(withTitle: artistOrCompilation)
        if artistMenuItem == nil {
            artistMenuItem = NSMenuItem(title: artistOrCompilation, action: #selector(artistMenuItemSelected(_:)), keyEquivalent: "")
            artistMenuItem?.target = self
            artistMenuItem?.submenu = NSMenu()
            allTracksMenu.addItem(artistMenuItem!)
        }
        var albumMenuItem: NSMenuItem? = artistMenuItem?.submenu?.item(withTitle: album)
        if albumMenuItem == nil {
            albumMenuItem = NSMenuItem(title: album, action: #selector(albumMenuItemSelected(_:)), keyEquivalent: "")
            albumMenuItem?.target = self
            albumMenuItem?.submenu = NSMenu()
            artistMenuItem?.submenu?.addItem(albumMenuItem!)
        }
        if let n = albumMenuItem?.submenu?.items.count {
            for i in 0..<n {
                if let id0 = albumMenuItem?.submenu?.item(at: i)?.tag, let pid0 = idToPid[id0], let discNo0 = pidToDiscNo[pid0], let trackNo0 = pidToTrackNo[pid0], discNo < discNo0 || discNo == discNo0 && trackNo < trackNo0 {
                    albumMenuItem?.submenu?.insertItem(menuItem, at: i)
                    return
                }
            }
        }
        albumMenuItem?.submenu?.addItem(menuItem)
    }

    @objc func trackMenuItemSelected(_ sender: AnyObject) {
        guard let id: Int = sender.tag else {return}
        guard let pid: String = idToPid[id] else {return}
        let name: String = do_play_track(pid: pid)
        if !name.isEmpty {
            updateRecentTracksMenu(name: name, id: id)
        }
        if name != sender.title {
            removeFromRecentTracksMenu(name: sender.title, id: id)
        }
    }

    func do_play_track(pid: String) -> String {
        let scpt = """
        tell application \(itm.quoted)
            set theTracks to every track whose persistent ID is \(pid.quoted)
            if count of theTracks is 1 then
                set theTrack to item 1 of theTracks
                play theTrack with once
                name of theTrack
            else
                ""
            end if
        end tell
        """
        return doAppleScript(script: scpt)
    }

    @objc func artistMenuItemSelected(_ sender: NSMenuItem) {
        // NOP
    }

    @objc func albumMenuItemSelected(_ sender: NSMenuItem) {
        // control+クリックまたは右クリックでシャッフル再生、単にクリックでノーマル再生
        guard let event = NSApp.currentEvent else {return}
        let controlKey: NSEvent.ModifierFlags = .control
        // MIDDLECLICK: 中クリックでもシャッフル
        let shuffle: Bool = NSEvent.modifierFlags.contains(controlKey) || event.type == .rightMouseUp || event.type == .otherMouseUp
        if let pids: [String] = sender.submenu?.items.map({idToPid[$0.tag] ?? ""}) {
            do_play_album(pids: pids, shuffle: shuffle)
        }
    }

    func do_play_album(pids: [String], shuffle: Bool = false) {
        let s = shuffle ? "true" : "false"
        let iAlbum = "iAlbum".quoted
        let scpt = """
        tell application \(itm.quoted)
            if exists playlist \(iAlbum) then
                set thePlaylist to playlist \(iAlbum)
            else
                set thePlaylist to make new playlist with properties {name:\(iAlbum)}
            end if
            --
            delete every track of thePlaylist
            --
            repeat with pid in {\(pids.map {$0.quoted}.joined(separator: ","))}
                duplicate (every track of playlist 1 whose persistent ID is pid) to thePlaylist
            end repeat
            --
            set shuffle enabled to \(s)
            play playlist \(iAlbum)
        end tell
        """
        let _ = doAppleScript(script: scpt)
    }

    // TRACKS
    // MARK: recent tracks menu
    var recentTracksItem: [PlaylistItem] = [] // or [TrackItem]
    var recentTracksMenuItemCount = 0

    func updateRecentTracksMenu(name: String, id: Int) {
        // メニュー項目を作成
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.title = name
        menuItem.tag = id
        menuItem.action = #selector(AppDelegate.trackMenuItemSelected(_:))
        if let pid = idToPid[id] {
            menuItem.toolTip = pidToToolTip[pid]
        }

        // 重複を避けるため name, id に合致する項目を recentTracksItem とメニューから削除
        for i in (0..<recentTracksItem.count).reversed() {
            if recentTracksItem[i].name == name && recentTracksItem[i].id == id {
                recentTracksItem.remove(at: i)
                if i < recentTracksMenuItemCount {
                    recentTracksMenu.removeItem(at: i)
                    recentTracksMenuItemCount -= 1
                }
            }
        }
        // recentTracksItem とメニューの先頭に追加
        recentTracksItem.insert(PlaylistItem(name: name, id: id), at: 0)
        recentTracksMenu.insertItem(menuItem, at: 0)
        recentTracksMenuItemCount += 1

        // 最大で maxRecent 個の項目だけ残す
        if maxRecent < recentTracksMenuItemCount {
            for _ in maxRecent..<recentTracksMenuItemCount {
                recentTracksMenu.removeItem(at: maxRecent)
                recentTracksMenuItemCount -= 1
            }
        }

        writeRecentTracksMenuToUserDefaults()
    }

    func clearRecentTracksMenu() {
        // recentTracksItem と メニューを空にする
        recentTracksItem = []
        for _ in 0..<recentTracksMenuItemCount {
            recentTracksMenu.removeItem(at: 0)
            recentTracksMenuItemCount -= 1
        }
    }

    func setupRecentTracksMenu() {
        // userDefaults から読み出し
        guard let recentTracksPid: [String] = ud.object(forKey: MyKey.recentTracksPid) as? [String] else {return}
        // recentTracksPid から recentTracksItem を設定
        for i in (0..<recentTracksPid.count).reversed() {
            let pid = recentTracksPid[i]
            if let name = pidToName[pid], let id = pidToId[pid] {
                recentTracksItem.insert(PlaylistItem(name: name, id: id), at: 0)
            }
        }
        // recentTracksItem からメニューを設定
        let max = [maxRecent, recentTracksItem.count].min()!
        for i in (0..<max).reversed() {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = recentTracksItem[i].name
            menuItem.tag = recentTracksItem[i].id
            menuItem.action = #selector(AppDelegate.trackMenuItemSelected(_:))
            if let pid = idToPid[recentTracksItem[i].id] {
                menuItem.toolTip = pidToToolTip[pid]
            }
            recentTracksMenu.insertItem(menuItem, at: 0)
            recentTracksMenuItemCount += 1
        }

        //doGlobalRecent()
    }

    func removeFromRecentTracksMenu(name: String, id: Int) {
        for i in (0..<recentTracksItem.count).reversed() {
            // name, id に合致する項目を recentTracksItem とメニューから削除
            if recentTracksItem[i].name == name && recentTracksItem[i].id == id {
                recentTracksItem.remove(at: i)
                if i < recentTracksMenuItemCount {
                    recentTracksMenu.removeItem(at: i)
                    recentTracksMenuItemCount -= 1
                }
            }
        }
        // 補欠
        let max = [maxRecent, recentTracksItem.count].min()!
        for i in (recentTracksMenuItemCount..<max).reversed() {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = recentTracksItem[i].name
            menuItem.tag = recentTracksItem[i].id
            menuItem.action = #selector(AppDelegate.trackMenuItemSelected(_:))
            if let pid = idToPid[recentTracksItem[i].id] {
                menuItem.toolTip = pidToToolTip[pid]
            }
            recentTracksMenu.insertItem(menuItem, at: i)
            recentTracksMenuItemCount += 1
        }

        writeRecentTracksMenuToUserDefaults()
    }

    func writeRecentTracksMenuToUserDefaults() {
        // userDefaults に書き出し
        ud.set(recentTracksItem.filter {idToPid[$0.id] != nil}.map {idToPid[$0.id]!}, forKey: MyKey.recentTracksPid)
        ud.synchronize()
    }

    // MARK: Now Playing
    func setTitle(title aTitle: String? = nil) {
        // LASTPLAYLIST
        // let full = aTitle ?? doAppleScript(script: "tell application \(itm.quoted) to name of current track")
        var full = aTitle ?? doAppleScript(script: "tell application \(itm.quoted) to name of current track")
        full = full.isEmpty ? lastPlaylist : full
        //
        let truncated = full.truncated(lessWideThan: showTitleMaxWidth)
        title = !showTitle ? "" : truncated.isEmpty ? myName : truncated
        toolTip = full.isEmpty ? myName : full
    }

    // MARK: artwork
    func setImage() {
        if !showArtwork {
            artwork = nil
            return
        }
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: "tell application \(itm.quoted) to data of artwork 1 of current track") else {return}
        let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
        let image = NSImage(data: output.data)
        // artwork = image
        // artwrok = image?.scaledCopy(sizeOfLargerSide: 20)
        artwork = image?.resizedCopy(w: 20, h: 20)
    }

    func setButton() {
        statusItem.button?.image = symbol
        statusItem2.button?.image = artwork
        statusItem2.button?.title = title.isEmpty && artwork == nil ? myName : title
        statusItem.button?.toolTip = toolTip
        statusItem2.button?.toolTip = toolTip
    }

    func setButton2() {
        playPauseButton.image = symbol2
    }
}

// MARK: - NSNumber
extension NSNumber {
    // 16 進文字列表現
    func hex() -> String {
        return String(format: "%016lX", UInt64(truncating: self))
    }
}

// MARK: - NSImage
extension NSImage {
    // SHOWARTWORK
    // - objective c - How to resize NSImage? - Stack Overflow
    // - https://stackoverflow.com/questions/11949250/how-to-resize-nsimage/38442746#38442746

    func scaledCopy(sizeOfLargerSide: CGFloat) ->  NSImage {
        var newW: CGFloat
        var newH: CGFloat
        var scaleFactor: CGFloat

        if (self.size.width > self.size.height) {
            scaleFactor = self.size.width / sizeOfLargerSide
            newW = sizeOfLargerSide
            newH = self.size.height / scaleFactor
        } else{
            scaleFactor = self.size.height / sizeOfLargerSide
            newH = sizeOfLargerSide
            newW = self.size.width / scaleFactor
        }

        return resizedCopy(w: newW, h: newH)
    }

    func resizedCopy(w: CGFloat, h: CGFloat) -> NSImage {
        let destSize = NSMakeSize(w, h)
        let newImage = NSImage(size: destSize)

        newImage.lockFocus()

        self.draw(in: NSRect(origin: .zero, size: destSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: CGFloat(1))

        newImage.unlockFocus()

        guard let data = newImage.tiffRepresentation,
              let result = NSImage(data: data)
        else {return NSImage()}

        return result
    }

    // SHUFFLEREPEAT
    // - NSImage に Tint Color を適用する機能を拡張する - Qiita
    // - https://qiita.com/usagimaru/items/3a6ffa431e52817f15da
    func withTintColor(_ color: NSColor, using operation: NSCompositingOperation = .sourceAtop) -> NSImage {
        guard isTemplate else {return self}
        guard let image = self.copy() as? NSImage else {return self}
        image.lockFocus()
        color.set()
        let bounds = NSRect(origin: .zero, size: image.size)
        bounds.fill(using: operation)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

// MARK: - String
extension String {
    // 文字列をダブルクォートで囲む
    var quoted: String {
        get {return "\"" + self.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""}
    }

    // 切り詰める
    func truncated(lessWideThan maxWidth: CGFloat, font: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize), ellipsis: String = "…") -> String {
        let textAttributes: [NSAttributedString.Key:Any] = [NSAttributedString.Key.font:font]
        var s = self
        if (s as NSString).size(withAttributes: textAttributes).width <= maxWidth {return s}
        while maxWidth < ((s + ellipsis) as NSString).size(withAttributes: textAttributes).width {
            s = String(s.dropLast())
        }
        return (s + ellipsis)
    }
}

// TRACKS
// MARK: - iTunesLibrary
// ITL
extension ITLibMediaItem: Comparable {
    public static func == (lhs: ITLibMediaItem, rhs: ITLibMediaItem) -> Bool {
        func ne(_ sl: String?, _ sr: String?) -> Bool {
            //return (sl ?? "").localizedCaseInsensitiveCompare(sr ?? "") != .orderedSame
            return (sl ?? "").localizedStandardCompare(sr ?? "") != .orderedSame
        }

        if ne(lhs.artist?.name, rhs.artist?.name) {return false}
        if ne(lhs.album.title, rhs.album.title) {return false}
        if lhs.album.discNumber != rhs.album.discNumber {return false}
        if lhs.trackNumber != rhs.trackNumber {return false}
        if ne(lhs.title, rhs.title) {return false}
        return true
    }

    public static func < (lhs: ITLibMediaItem, rhs: ITLibMediaItem) -> Bool {
        func lt(_ sl: String?, _ sr: String?) -> Bool {
            //return (sl ?? "").localizedCaseInsensitiveCompare(sr ?? "") == .orderedAscending
            return (sl ?? "").localizedStandardCompare(sr ?? "") == .orderedAscending
        }

        func gt(_ sl: String?, _ sr: String?) -> Bool {
            //return (sl ?? "").localizedCaseInsensitiveCompare(sr ?? "") == .orderedDescending
            return (sl ?? "").localizedStandardCompare(sr ?? "") == .orderedDescending
        }

        if lhs.album.isCompilation && !rhs.album.isCompilation {return true}
        if !lhs.album.isCompilation && rhs.album.isCompilation {return false}

        if !lhs.album.isCompilation && !rhs.album.isCompilation {
            if lt(lhs.artist?.name, rhs.artist?.name) {return true}
            if gt(lhs.artist?.name, rhs.artist?.name) {return false}
        }

        if lt(lhs.album.title, rhs.album.title) {return true}
        if gt(lhs.album.title, rhs.album.title) {return false}

        if lhs.album.discNumber < rhs.album.discNumber {return true}
        if lhs.album.discNumber > rhs.album.discNumber {return false}

        if lhs.trackNumber < rhs.trackNumber {return true}
        if lhs.trackNumber > rhs.trackNumber {return false}

        if lt(lhs.title, rhs.title) {return true}
        if gt(lhs.title, rhs.title) {return false}

        return false
    }
}

// MARK: - NSStatusBarButton
// - delay - NSButton with delayed NSMenu - Objective-C/Cocoa - Stack Overflow
// - https://stackoverflow.com/questions/9196109/nsbutton-with-delayed-nsmenu-objective-c-cocoa
extension NSStatusBarButton {
    // - 【Swift5】Extensions を使用してプロパティを追加する方法 | なんくるないさーエンジニア
    // - https://exgyaruo.com/programming/swift/extensions-add-stored-property
    //
    private static var _singleAction: Selector? = #selector(AppDelegate.playPauseAction(_:))
    private static var _doubleAction: Selector? = #selector(AppDelegate.nextTrackAction(_:))
    private static var _tripleAction: Selector? = #selector(AppDelegate.backTrackAction(_:))
    private static var _longBeganAction: Selector? = #selector(AppDelegate.longPressBeganAction(_:))
    private static var _longAction: Selector? = #selector(AppDelegate.longPressEndedAction(_:))
    private static var _mouseIsDown: Bool = false
    private static var _mouseDownUniquenessCounter: Int = 0
    private static var _delayedItem: DispatchWorkItem?
    //
    var singleAction: Selector? {
        get {return NSStatusBarButton._singleAction}
        set {NSStatusBarButton._singleAction = newValue}
    }
    var doubleAction: Selector? {get {return NSStatusBarButton._doubleAction}}
    var tripleAction: Selector? {get {return NSStatusBarButton._tripleAction}}
    var longBeganAction: Selector? {get {return NSStatusBarButton._longBeganAction}}
    var longAction: Selector? {get {return NSStatusBarButton._longAction}}
    var mouseIsDown: Bool {
        get {return NSStatusBarButton._mouseIsDown}
        set {NSStatusBarButton._mouseIsDown = newValue}
    }
    var mouseDownUniquenessCounter: Int {
        get {return NSStatusBarButton._mouseDownUniquenessCounter}
        set {NSStatusBarButton._mouseDownUniquenessCounter = newValue}
    }
    var delayedItem: DispatchWorkItem? {
        get {return NSStatusBarButton._delayedItem}
        set {NSStatusBarButton._delayedItem = newValue}
    }

    open override func mouseDown(with event: NSEvent) {
        // MULTIITEM
        if tag != StatusBarButtonType.multiClick {super.mouseDown(with: event); return}

        if singleAction == nil {singleAction = action}
        delayedItem?.cancel()

        mouseIsDown = true
        mouseDownUniquenessCounter += 1
        let mouseDownUniquenessCounterCopy = mouseDownUniquenessCounter

        self.highlight(true)

        let delayInSeconds = NSEvent.doubleClickInterval
        delayedItem = DispatchWorkItem {[weak self] in
            guard let self = self else {return}
            if self.mouseIsDown && mouseDownUniquenessCounterCopy == self.mouseDownUniquenessCounter {
                self.sendAction(self.longBeganAction, to: self.target)
                self.action = self.longAction
            }
            if self.action != self.longAction {
                self.sendAction(self.action, to: self.target)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayInSeconds * 1000)), execute: delayedItem!)

        self.action = nil
        switch event.clickCount {
        case 1: self.action = singleAction
        case 2: self.action = doubleAction
        case 3: self.action = tripleAction
        default: self.action = nil
        }
    }

    open override func mouseUp(with event: NSEvent) {
        // MULTIITEM
        if tag != StatusBarButtonType.multiClick {super.mouseUp(with: event); return}

        mouseIsDown = false
        if self.action == longAction {
            self.sendAction(self.action, to: self.target)
        }
        self.highlight(false)
    }
}

// MARK: - MySlider
// SEEKBAR
class MySliderCell: NSSliderCell {
    // - ノブなしNSSliderでシークバーを作る — Genji App Blog
    // - https://genjiapp.com/blog/2020/03/19/create-seek-bar-using-knobless-nsslider.html
    // KNOB
    var hideKnob: Bool = true

    /*
    override func knobRect(flipped: Bool) -> NSRect {
        return NSRect.zero
    }
     */

    // - Objective-C - NSSliderのThumb(持つところ)の画像を変更したい｜teratail
    // - https://teratail.com/questions/249773

    // Slider の現在値が、全体の 何% にあたるのかを示す
    var currentValuePercentage: CGFloat {
        get {return CGFloat((self.doubleValue - self.minValue) / (self.maxValue - self.minValue))}
    }

    // KNOB
    override func drawKnob(_ knobRect: NSRect) {
        if hideKnob {return}
        //
        let knobSize: NSSize = NSMakeSize(4, 10)
        let knobRadius: CGFloat = knobSize.width / 2.0
        let adjustedRect: NSRect = NSRect(origin: NSMakePoint(knobRect.origin.x + (knobRect.size.width - knobSize.width) * currentValuePercentage, knobRect.origin.y + (knobRect.size.height - knobSize.height) / 2.0), size: knobSize)
        let bg : NSBezierPath = NSBezierPath(roundedRect: adjustedRect, xRadius: knobRadius, yRadius: knobRadius)
        NSColor.labelColor.setFill()
        bg.fill()
        //
        // NSColor.controlBackgroundColor.setStroke()
        // NSColor.lightGray.setStroke() // XXX
        NSColor.systemGray.setStroke() // XXX
        bg.stroke()
        //
        bg.close()
    }

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let fullRect = NSRect(origin: rect.origin, size: NSMakeSize(rect.size.width, CGFloat(3)))
        let barRadius: CGFloat = CGFloat(1.5) // 2.5
        // Slider のバー全体を塗る
        let bg: NSBezierPath = NSBezierPath(roundedRect: fullRect, xRadius: barRadius, yRadius: barRadius)
        NSColor.disabledControlTextColor.setFill() // #b2b2b2 / #656565 // 背景より暗い/明るい色
        //
        bg.fill()
        bg.close()
        // Slider の左端から、現在の値に相当する箇所までアクセントカラーで塗る
        let leftRect: NSRect = NSRect(origin: fullRect.origin, size: NSMakeSize(fullRect.size.width * self.currentValuePercentage, fullRect.size.height))
        let active: NSBezierPath = NSBezierPath(roundedRect: leftRect, xRadius: barRadius, yRadius: barRadius)
        // NOACCENTCOLOR - アクセントカラーの代わりに labelColor で塗る
        // NSColor.controlAccentColor.setFill()
        NSColor.labelColor.setFill()
        //
        active.fill()
        active.close()
    }
}

// KNOB
class MySlider: NSSlider {
    var trackingArea: NSTrackingArea? = nil

    override func updateTrackingAreas() {
        if trackingArea != nil {
            removeTrackingArea(trackingArea!)
        }
        let options: NSTrackingArea.Options = [.inVisibleRect, .mouseEnteredAndExited, .activeAlways] // 非アクティブ時でもマウストラッキングを有効にする
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = MySliderCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseEntered(with event: NSEvent) {
        (cell as? MySliderCell)?.hideKnob = false
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        (cell as? MySliderCell)?.hideKnob = true
        needsDisplay = true
    }
}

// MARK: - WheelButton
class WheelButton: NSButton {
    override open func scrollWheel(with event: NSEvent) {
        if event.deltaY < 0 {sendAction(#selector(AppDelegate.volumeUpAction(_:)), to: nil)}
        else if 0 < event.deltaY {sendAction(#selector(AppDelegate.volumeDownAction(_:)), to: nil)}
    }
}
