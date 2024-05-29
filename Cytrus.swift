//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 21/5/2024.
//

import Foundation
import QuartzCore.CAMetalLayer

public struct Cytrus {
    public static let shared = Cytrus()
    
    public let cytrusObjC = CytrusObjC.shared()
    
    public func insert(game url: URL) {
        cytrusObjC.insert(game: url)
    }
    
    public func step() {
        cytrusObjC.step()
    }
    
    public func information(_ url: URL) -> (title: String, iconData: Data) {
        let information = cytrusObjC.gameInformation.information(for: url)
        return (information.title, information.iconData)
    }
    
    public func configure(_ primaryScreen: CAMetalLayer, _ primaryScreenSize: CGSize) {
        cytrusObjC.configure(primaryLayer: primaryScreen, primarySize: primaryScreenSize)
    }
    
    public func orientationChanged(_ orientation: UIInterfaceOrientation, _ primaryScreenSize: CGSize) {
        cytrusObjC.orientationChanged(orientation: orientation, with: primaryScreenSize)
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
    
    public func pausePlay(_ pausePlay: Bool) {
        cytrusObjC.pausePlay(pausePlay)
    }
}
