//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 21/5/2024.
//

import Foundation
import QuartzCore.CAMetalLayer
import MetalKit

@objc public class Cytrus : NSObject {
    public static let shared = Cytrus()
    
    public let cytrusObjC = CytrusObjC.shared()
    
    public func getVulkanLibrary() {
        cytrusObjC.getVulkanLibrary()
    }
    
    public func setMTKViewSize( size: CGSize) {
        cytrusObjC.setMTKViewSize(size)
    }
    
    public func setMTKView(_ mtkView: MTKView, _ size: CGSize) {
        cytrusObjC.setMTKView(mtkView, size: size)
    }
    
    public func run(_ url: URL) {
        cytrusObjC.run(url)
    }
    
    public func updateSettings() {
        cytrusObjC.updateSettings()
    }
    
    public func orientationChanged(_ orientation: UIInterfaceOrientation, _ mtkView: MTKView) {
        cytrusObjC.orientationChanged(orientation, mtkView: mtkView)
    }
    
    public func information(_ url: URL) -> (title: String, iconData: Data?) {
        let information = cytrusObjC.gameInformation.information(for: url)
        return (information.title, information.iconData)
    }
    
    public func thumbstickMoved(_ thumbstick: VirtualControllerAnalogType, _ x: Float, _ y: Float) {
        cytrusObjC.thumbstickMoved(thumbstick, x: CGFloat(x), y: CGFloat(y))
    }
    
    public func touchBegan(_ point: CGPoint) {
        cytrusObjC.touchBegan(at: point)
    }
    
    public func touchEnded() {
        cytrusObjC.touchEnded()
    }
    
    public func touchMoved(_ point: CGPoint) {
        cytrusObjC.touchMoved(at: point)
    }
    
    public func virtualControllerButtonDown(_ button: VirtualControllerButtonType) {
        cytrusObjC.virtualControllerButtonDown(button)
    }
    
    public func virtualControllerButtonUp(_ button: VirtualControllerButtonType) {
        cytrusObjC.virtualControllerButtonUp(button)
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
    
    public func `import`(game url: URL) -> InstallStatus {
        cytrusObjC.importGame(url)
    }
    
    public func installed() -> [URL] {
        cytrusObjC.installedGamePaths() as! [URL]
    }
    
    public func system() -> [URL] {
        cytrusObjC.systemGamePaths() as! [URL]
    }
}
