//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 12/7/2024.
//

import Foundation
import MetalKit
import UIKit

public struct Cytrus : @unchecked Sendable {
    public static var shared = Cytrus()
    
    public init() {}
    
    fileprivate let cytrusObjC = CytrusObjC.shared()
    
    public func information(for cartridge: URL) -> CytrusGameInformation {
        cytrusObjC.informationForGame(at: cartridge)
    }
    
    public func allocateVulkanLibrary() {
        cytrusObjC.allocateVulkanLibrary()
    }
    
    public func deallocateVulkanLibrary() {
        cytrusObjC.deallocateVulkanLibrary()
    }
    
    public func allocateMetalLayer(for layer: CAMetalLayer, with size: CGSize, isSecondary: Bool = false) {
        cytrusObjC.allocateMetalLayer(layer, with: size, isSecondary: isSecondary)
    }
    
    public func deallocateMetalLayers() {
        cytrusObjC.deallocateMetalLayers()
    }
    
    public func insertCartridgeAndBoot(with url: URL) {
        cytrusObjC.insertCartridgeAndBoot(url)
    }
    
    public func importGame(at url: URL) -> ImportResultStatus {
        cytrusObjC.importGame(at: url)
    }
    
    public func touchBegan(at point: CGPoint) {
        cytrusObjC.touchBegan(at: point)
    }
    
    public func touchEnded() {
        cytrusObjC.touchEnded()
    }
    
    public func touchMoved(at point: CGPoint) {
        cytrusObjC.touchMoved(at: point)
    }
    
    public func virtualControllerButtonDown(_ button: VirtualControllerButtonType) {
        cytrusObjC.virtualControllerButtonDown(button)
    }
    
    public func virtualControllerButtonUp(_ button: VirtualControllerButtonType) {
        cytrusObjC.virtualControllerButtonUp(button)
    }
    
    public func thumbstickMoved(_ thumbstick: VirtualControllerAnalogType, _ x: Float, _ y: Float) {
        cytrusObjC.thumbstickMoved(thumbstick, x: CGFloat(x), y: CGFloat(y))
    }
    
    public func isPaused() -> Bool {
        cytrusObjC.isPaused()
    }
    
    public func pausePlay(_ pausePlay: Bool) {
        cytrusObjC.pausePlay(pausePlay)
    }
    
    public func stop() {
        cytrusObjC.stop()
    }
    
    public func running() -> Bool {
        cytrusObjC.running()
    }
    
    public func stopped() -> Bool {
        cytrusObjC.stopped()
    }
    
    public func orientationChange(with orientation: UIInterfaceOrientation, using mtkView: UIView) {
        cytrusObjC.orientationChanged(orientation, metalView: mtkView)
    }
    
    public func installed() -> [URL] {
        cytrusObjC.installedGamePaths() as? [URL] ?? []
    }
        
    public func system() -> [URL] {
        cytrusObjC.systemGamePaths() as? [URL] ?? []
    }
    
    public func updateSettings() {
        cytrusObjC.updateSettings()
    }
    
    public var stepsPerHour: UInt16 {
        get {
            cytrusObjC.stepsPerHour()
        }
        
        set {
            cytrusObjC.setStepsPerHour(newValue)
        }
    }
    
    public func loadState() { cytrusObjC.loadState() }
    public func saveState() { cytrusObjC.saveState() }
    
    public func saves(for identifier: UInt64) -> [SaveStateInfo] { cytrusObjC.saveStates(identifier) }
    public func saveStatePath(for identifier: UInt64) -> String { cytrusObjC.saveStatePath(identifier) }
    
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
    
    public let multiplayer = Multiplayer.shared
}
