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
    public static let shared = Cytrus()
    
    fileprivate let cytrusObjC = CytrusObjC.shared()
    
    public func informationForGame(at url: URL) -> CytrusGameInformation {
        cytrusObjC.informationForGame(at: url)
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
    
    public func orientationChange(with orientation: UIInterfaceOrientation, using mtkView: MTKView) {
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
}
