//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 21/5/2024.
//

import Foundation

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
}
