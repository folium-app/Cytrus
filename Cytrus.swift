//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//

import Foundation
import MetalKit
import UIKit

public struct SystemSaveGame {
    public static var shared: SystemSaveGame = .init()
    
    public var systemLanguage: Int { .init(Cytrus.shared.emulator.systemLanguage()) }
    public func set(_ systemLanguage: Int) { Cytrus.shared.emulator.set(systemLanguage: .init(systemLanguage))}
    
    public var username: String { Cytrus.shared.emulator.username() }
    public func set(_ username: String) { Cytrus.shared.emulator.set(username: username) }
}

public enum CytrusAnalogType : UInt32 {
    case circlePad      = 713
    case circlePadUp    = 714
    case circlePadDown  = 715
    case circlePadLeft  = 716
    case circlePadRight = 717
    
    case cStick         = 718
    case cStickUp       = 719
    case cStickDown     = 720
    case cStickLeft     = 721
    case cStickRight    = 722
}

public enum CytrusButtonType : UInt32 {
    case a      = 700
    case b      = 701
    case x      = 702
    case y      = 703
    case start  = 704
    case select = 705
    case home   = 706
    case zl     = 707
    case zr     = 708
    case up     = 709
    case down   = 710
    case left   = 711
    case right  = 712
    case l      = 773
    case r      = 774
    case debug  = 781
    case gpio14 = 782
    
    public static func type(_ string: String) -> Self? {
        switch string {
        case "a": .a
        case "b": .b
        case "x": .x
        case "y": .y
        case "dpadUp": .up
        case "dpadDown": .down
        case "dpadLeft": .left
        case "dpadRight": .right
        case "l": .l
        case "r": .r
        case "zl": .zl
        case "zr": .zr
        case "home": .home
        case "minus": .select
        case "plus": .start
        default: nil
        }
    }
}

public enum CytrusImportResult : UInt32 {
    case success          = 0
    case failedToOpenFile = 1
    case fileNotFound     = 2
    case aborted          = 3
    case invalid          = 4
    case encrypted        = 5
}

public struct Cytrus {
    public static var shared: Cytrus = .init()
    
    public var emulator: CytrusObjC = .shared()
    public var multiplayer: Multiplayer = .shared
    
    public init() {
        emulator.loadConfig() // loads the cfg for birth date, username, etc
    }
}

extension Cytrus {
    public func diskCacheCallback(_ callback: @escaping (UInt8, Int, Int) -> Void) {
        emulator.disk_cache_callback = callback
    }
    
    public func information(_ url: URL) -> GameInformation { emulator.information(from: url) }
    
    public func allocate() { emulator.allocate() }
    public func deallocate() { emulator.deallocate() }
    
    public func initialize(_ layer: CAMetalLayer, _ size: CGSize, _ secondary: Bool = false) {
        emulator.initialize(layer, size: size, secondary: secondary)
    }
    public func deinitialize() { emulator.deinitialize() }
    
    public func insert(_ url: URL) { emulator.insert(from: url) }
    
    public func `import`(_ url: URL) -> CytrusImportResult { .init(rawValue: emulator.import(from: url)) ?? .success }
    
    public func touchBegan(at point: CGPoint) {
        emulator.touchBegan(at: point)
    }
    
    public func touchEnded() {
        emulator.touchEnded()
    }
    
    public func touchMoved(at point: CGPoint) {
        emulator.touchMoved(at: point)
    }
    
    public func input(_ slot: Int, _ button: CytrusButtonType, _ pressed: Bool) {
        emulator.input(.init(slot), button: button.rawValue, pressed: pressed)
    }
    
    public func thumbstickMoved(_ thumbstick: CytrusAnalogType, _ x: Float, _ y: Float) {
        emulator.thumbstickMoved(thumbstick.rawValue, x: CGFloat(x), y: CGFloat(y))
    }
    
    public func isPaused() -> Bool {
        emulator.isPaused()
    }
    
    public func pausePlay(_ pausePlay: Bool) {
        emulator.pausePlay(pausePlay)
    }
    
    public func stop() {
        emulator.stop()
    }
    
    public func running() -> Bool {
        emulator.running()
    }
    
    public func stopped() -> Bool {
        emulator.stopped()
    }
    
    public func orientationChange(with orientation: UIInterfaceOrientation, using mtkView: UIView) {
        emulator.orientationChanged(orientation, metalView: mtkView)
    }
    
    public func installed() -> [URL] {
        emulator.installedGamePaths() as? [URL] ?? []
    }
        
    public func system() -> [URL] {
        emulator.systemGamePaths() as? [URL] ?? []
    }
    
    public func updateSettings() {
        emulator.updateSettings()
    }
    
    public var stepsPerHour: UInt16 {
        get { emulator.stepsPerHour() }
        set { emulator.setStepsPerHour(newValue) }
    }
    
    public func loadState(_ completionHandler: @escaping (Bool) -> Void) { completionHandler(emulator.loadState()) }
    public func saveState(_ completionHandler: @escaping (Bool) -> Void) { completionHandler(emulator.saveState()) }
    
    public func saves(for identifier: UInt64) -> [SaveStateInfo] { emulator.saveStates(identifier) }
    public func saveStatePath(for identifier: UInt64) -> String { emulator.saveStatePath(identifier) }
    
    public struct Multiplayer : @unchecked Sendable {
        public static let shared = Multiplayer()
        
        let multiplayerObjC = MultiplayerManager.shared()
        
        public var rooms: [NetworkRoom] {
            multiplayerObjC.rooms()
        }
        
        public var state: StateChange {
            multiplayerObjC.state()
        }
        
        public func connect(to room: NetworkRoom, with username: String, and password: String? = nil,
                            error errorHandler: @escaping (ErrorChange) -> Void, state stateHandler: @escaping (StateChange) -> Void) {
            multiplayerObjC.connect(room, withUsername: username, andPassword: password,
                                    withErrorChange: errorHandler, withStateChange: stateHandler)
        }
        
        public func disconnect() {
            multiplayerObjC.disconnect()
        }
        
        public func updateWebAPIURL() {
            multiplayerObjC.updateWebAPIURL()
        }
    }
}
