//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 5/7/2026.
//

import AVFoundation
import Foundation
import MetalKit

public enum CytrusButton : Int32 {
    case a = 700
    case b = 701
    case x = 702
    case y = 703
    case start = 704
    case select = 705
    case home = 706
    case zl = 707
    case zr = 708
    case up = 709
    case down = 710
    case left = 711
    case right = 712
    case circlePad = 713
    case circlePadUp = 714
    case circlePadDown = 715
    case circlePadLeft = 716
    case circlePadRight = 717
    case cStick = 718
    case cStickUp = 719
    case cStickDown = 720
    case cStickLeft = 771
    case cStickRight = 772
    case leftTrigger = 773
    case rightTrigger = 774
    case debug = 781
    case gpio14 = 782
    
    public var int32: Int32 { rawValue }
};

public struct SendableBoxart : @unchecked Sendable {
    public let data: NSData
}

public actor CytrusSystem {
    private var fileManager: FileManager = .default
    
    public init() {}
    
    public func printAbout() {
        cytrus.print_about()
    }
    
    public func initializeLogging() {
        cytrus.initialize_logging()
    }
    
    public func insertDisc(at url: URL) {
        cytrus.insert_disc(std.string(url.path))
    }
    
    public func set(change: Bool = false, isRunning: Bool = false) {
        if change {
            running = isRunning
        }
    }
    
    public var running: Bool {
        get {
            cytrus.is_running()
        }
        set {
            cytrus.is_running(true, newValue)
        }
    }
    
    public func set(change: Bool = false, isPaused: Bool = false) {
        if change {
            paused = isPaused
        }
    }
    
    public var paused: Bool {
        get {
            cytrus.is_paused()
        }
        set {
            cytrus.is_paused(true, newValue)
        }
    }
    
    public func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error, error.localizedDescription)
        }
        
        cytrus.start()
    }
    
    public func stop() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print(error, error.localizedDescription)
        }
        
        cytrus.stop()
    }
    
    public func set(layer: CAMetalLayer, height: Double, width: Double, secondary: Bool) {
        cytrus.set_screens(Unmanaged.passUnretained(layer).toOpaque(), height, width, secondary)
    }
    
    public nonisolated func press(button: CytrusButton) {
        cytrus.press_button(button.int32)
    }
    
    public nonisolated func release(button: CytrusButton) {
        cytrus.release_button(button.int32)
    }
    
    public func touchBegan(at point: CGPoint) {
        cytrus.touch_began(Float(point.x), Float(point.y))
    }
    
    public func touchEnded() {
        cytrus.touch_ended()
    }
    
    public func touchMoved(at point: CGPoint) {
        cytrus.touch_moved(Float(point.x), Float(point.y))
    }
    
    public nonisolated func moveThumbstick(with id: Int32, x: Float, y: Float) {
        cytrus.move_thumbstick(id, x, y)
    }
    
    public func setSetting<T>(setting: cytrus.SETTING, value: T) {
        switch value {
        case let boolSetting as Bool:
            cytrus.set_setting(setting, boolSetting)
        case let intSetting as Int:
            cytrus.set_setting(setting, Int32(intSetting))
        case let stringSetting as String:
            cytrus.set_setting(setting, std.string(stringSetting))
        default:
            break
        }
    }
    
    public func boxart(for url: URL) -> SendableBoxart {
        SendableBoxart(data: NSData(bytes: cytrus.icon_from_disc(std.string(url.path)),
                                    length: 48 * 48 * MemoryLayout<UInt16>.size))
    }
    
    public func title(for url: URL) -> String {
        String(cytrus.title_from_disc(std.string(url.path)))
    }
    
    
    public nonisolated func ledStatusDidChange(callback: cytrus.LEDStatusChangedCallback) {
        cytrus.led_status_changed_callback(callback)
    }
}
