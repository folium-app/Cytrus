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
    
    public func information(for cartridge: URL) -> CytrusGameInformation {
        emulator.informationForGame(at: cartridge)
    }
    
    public func allocateVulkanLibrary() {
        emulator.allocateVulkanLibrary()
    }
    
    public func deallocateVulkanLibrary() {
        emulator.deallocateVulkanLibrary()
    }
    
    public func allocateMetalLayer(for layer: CAMetalLayer, with size: CGSize, isSecondary: Bool = false) {
        emulator.allocateMetalLayer(layer, with: size, isSecondary: isSecondary)
    }
    
    public func deallocateMetalLayers() {
        emulator.deallocateMetalLayers()
    }
    
    public func insertCartridgeAndBoot(with url: URL) {
        emulator.insertCartridgeAndBoot(url)
    }
    
    public func importGame(at url: URL) -> ImportResultStatus {
        emulator.importGame(at: url)
    }
    
    public func touchBegan(at point: CGPoint) {
        emulator.touchBegan(at: point)
    }
    
    public func touchEnded() {
        emulator.touchEnded()
    }
    
    public func touchMoved(at point: CGPoint) {
        emulator.touchMoved(at: point)
    }
    
    public func virtualControllerButtonDown(_ button: VirtualControllerButtonType) {
        emulator.virtualControllerButtonDown(button)
    }
    
    public func virtualControllerButtonUp(_ button: VirtualControllerButtonType) {
        emulator.virtualControllerButtonUp(button)
    }
    
    public func thumbstickMoved(_ thumbstick: VirtualControllerAnalogType, _ x: Float, _ y: Float) {
        emulator.thumbstickMoved(thumbstick, x: CGFloat(x), y: CGFloat(y))
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
        get {
            emulator.stepsPerHour()
        }
        
        set {
            emulator.setStepsPerHour(newValue)
        }
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
