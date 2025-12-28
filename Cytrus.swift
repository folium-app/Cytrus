//
//  Cytrus.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 1/7/2025.
//

import Foundation
import MetalKit
import UIKit

public actor SystemSaveGame {
    var emulator: CytrusEmulator = .shared()
    
    public var systemLanguage: Int { .init(emulator.systemLanguage()) }
    public func set(_ systemLanguage: Int) { emulator.set(systemLanguage: .init(systemLanguage))}
    
    public var username: String { emulator.username() }
    public func set(_ username: String) { emulator.set(username: username) }
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
        case "a", "circle": .a
        case "b", "cross": .b
        case "x", "triangle": .x
        case "y", "square": .y
        case "up", "dpadUp": .up
        case "down", "dpadDown": .down
        case "left", "dpadLeft": .left
        case "right", "dpadRight": .right
        case "l", "l1": .l
        case "r", "r1": .r
        case "zl", "l2": .zl
        case "zr", "r2": .zr
        case "home": .home
        case "minus", "select": .select
        case "plus", "start": .start
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

@objc
public enum CytrusNetworkRoomMemberError : UInt8, CustomStringConvertible {
    case lostConnection,
         hostKicked,
         
         unknownError,
         nameCollision,
         macCollision,
         consoleIDCollision,
         wrongVersion,
         wrongPassword,
         couldNotConnect,
         roomIsFull,
         hostBanned,
         
         permissionDenied,
         noSuchUser
    
    public var description: String {
        switch self {
        case .lostConnection:
            "Connection closed"
        case .hostKicked:
            "Kicked by the host"
        case .unknownError:
            "Some error [permissions to network device missing or something]"
        case .nameCollision:
            "Somebody is already using this name"
        case .macCollision:
            "Somebody is already using that mac-address"
        case .consoleIDCollision:
            "Somebody in the room has the same Console ID"
        case .wrongVersion:
            "The room version is not the same as for this RoomMember"
        case .wrongPassword:
            "The password doesn't match the one from the Room"
        case .couldNotConnect:
            "The room is not responding to a connection attempt"
        case .roomIsFull:
            "Room is already at the maximum number of players"
        case .hostBanned:
            "The user is banned by the host"
        case .permissionDenied:
            "The user does not have mod permissions"
        case .noSuchUser:
            "The nickname the user attempts to kick/ban does not exist"
        }
    }
    
    public var string: String { description }
}

@objc
public enum CytrusNetworkRoomMemberState : UInt8, CustomStringConvertible {
    case uninitialized,
         idle,
         joining,
         joined,
         moderator
    
    public var description: String {
        switch self {
        case .uninitialized:
            "Uninitialized"
        case .idle:
            "Idle"
        case .joining:
            "Joining"
        case .joined:
            "Joined"
        case .moderator:
            "Moderator"
        }
    }
    
    public var string: String { description }
}

@objc
public protocol CytrusMultiplayerManagerDelegate {
    func didReceiveChatEntry(_ entry: CytrusNetworkChatEntry)
    func didReceiveError(_ error: CytrusNetworkRoomMemberError)
    func didReceiveState(_ state: CytrusNetworkRoomMemberState)
}

@objcMembers // objcMembers for class
public class CytrusRoomMember : NSObject, Identifiable, @unchecked Sendable {
    public static func == (lhs: CytrusRoomMember, rhs: CytrusRoomMember) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id: UUID = .init()
    
    public let avatarURL, gameName, macAddress, nickname, username: String
    public let gameID: UInt64
    
    public init(avatarURL: String, gameName: String, macAddress: String, nickname: String, username: String, gameID: UInt64) {
        self.avatarURL = avatarURL
        self.gameName = gameName
        self.macAddress = macAddress
        self.nickname = nickname
        self.username = username
        self.gameID = gameID
    }
}

@objcMembers
public class CytrusNetworkChatEntry : NSObject, Identifiable, @unchecked Sendable {
    public static func == (lhs: CytrusNetworkChatEntry, rhs: CytrusNetworkChatEntry) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id: UUID = .init()
    
    public let date: Date = .now
    public let nickname, username, message: String
    
    init(nickname: String, username: String, message: String) {
        self.nickname = nickname
        self.username = username
        self.message = message
    }
}

public class CytrusChatEntry : NSObject, Identifiable, @unchecked Sendable {
    public static func == (lhs: CytrusChatEntry, rhs: CytrusChatEntry) -> Bool {
        lhs.id == rhs.id
    }
    
    public let id: UUID = .init()
    
    public let member: CytrusRoomMember
    public let entry: CytrusNetworkChatEntry
    
    public init(member: CytrusRoomMember, entry: CytrusNetworkChatEntry) {
        self.member = member
        self.entry = entry
    }
}

@objcMembers
public class CytrusRoom : NSObject, @unchecked Sendable {
    public let details, id, ip, name, owner, preferredGame, verifyUID: String
    public let port: UInt16
    public let maximumPlayers, netVersion, numberOfPlayers: UInt32
    public let preferredGameID: UInt64
    public let passwordLocked: Bool
    
    public var state: CytrusNetworkRoomMemberState
    
    public let members: [CytrusRoomMember]
    
    init(details: String, id: String, ip: String, name: String, owner: String, preferredGame: String, verifyUID: String,
         port: UInt16, maximumPlayers: UInt32, netVersion: UInt32, numberOfPlayers: UInt32,
         preferredGameID: UInt64, passwordLocked: Bool, state: CytrusNetworkRoomMemberState, members: [CytrusRoomMember]) {
        self.details = details
        self.id = id
        self.ip = ip
        self.name = name
        self.owner = owner
        self.preferredGame = preferredGame
        self.verifyUID = verifyUID
        self.port = port
        self.maximumPlayers = maximumPlayers
        self.netVersion = netVersion
        self.numberOfPlayers = numberOfPlayers
        self.preferredGameID = preferredGameID
        self.passwordLocked = passwordLocked
        self.state = state
        self.members = members
    }
}

public class Cytrus {
    public var emulator: CytrusEmulator = .shared()
    public var multiplayer: Multiplayer = .shared
    
    public init() {
        emulator.loadConfig() // loads the cfg for birth date, username, etc
    }
}

extension Cytrus {
    public func diskCacheCallback(_ callback: @escaping (UInt8, Int, Int) -> Void) {
        emulator.disk_cache_callback = callback
    }
    
    public func information(_ url: URL) -> CytrusGameInformation? {
        CytrusGameInformationManager(url: url).information()
    }
    
    public func allocate() { emulator.allocate() }
    public func deallocate() { emulator.deallocate() }
    
    public func initialize(_ layer: CAMetalLayer, _ size: CGSize, _ secondary: Bool = false) {
        if secondary {
            emulator.bottom(layer, size: size)
        } else {
            emulator.top(layer, size: size)
        }
    }
    public func deinitialize() { emulator.deinitialize() }
    
    public func insert(_ url: URL, _ callback: @escaping () -> Void) { emulator.insert(from: url, with: callback) }
    
    public func installCIA(_ url: URL, _ callback: @escaping () -> Void) -> Bool { emulator.installCIA(url, withCallback: callback) }
    
    public func bootHome(_ region: Int) -> URL {
        emulator.bootHome(region)
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
    
    public func button(button: CytrusButtonType, player: Int, pressed: Bool) {
        emulator.input(Int32(player), button: button.rawValue, pressed: pressed)
    }
    
    public func input(_ slot: Int, _ button: CytrusButtonType, _ pressed: Bool) {
        emulator.input(.init(slot), button: button.rawValue, pressed: pressed)
    }
    
    public func thumbstickMoved(_ thumbstick: CytrusAnalogType, _ x: Float, _ y: Float) {
        emulator.thumbstickMoved(thumbstick.rawValue, x: CGFloat(x), y: CGFloat(y))
    }
    
    public var isPaused: Bool {
        get {
            emulator.isPaused()
        }
        set {
            emulator.pause(newValue)
        }
    }
    
    public func pause(_ pause: Bool) {
        emulator.pause(pause)
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
    
    public func orientationChange(with orientation: UIInterfaceOrientation, using mtkView: UIView, _ secondary: Bool = false) {
        emulator.orientationChanged(orientation, metalView: mtkView, secondary: secondary)
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
    
    public func stateExists(_ identifier: UInt64, _ slot: Int) -> Bool { emulator.stateExists(identifier, forSlot: slot) }
    public func load(_ slot: Int) { emulator.load(slot) }
    public func save(_ slot: Int) { emulator.save(slot) }
    
    public func insertAmiibo(_ url: URL) -> Bool { emulator.insertAmiibo(url) }
    public func removeAmiibo() { emulator.removeAbiibo() }
    
    public func savesStates(for identifier: UInt64) -> [Any] { emulator.saveStates(identifier) }
    public func saveStatePath(_ identifier: UInt64, _ slot: Int) -> String { emulator.saveStatePath(identifier, slot) }
    
    public struct Multiplayer : @unchecked Sendable {
        public static let shared = Multiplayer()
        
        var multiplayerObjC: CytrusMultiplayerManager = .shared()
        
        public var connectedRoom: CytrusRoom? { multiplayerObjC.connectedRoom }
        public var entries: [CytrusNetworkChatEntry] { multiplayerObjC.entries as? [CytrusNetworkChatEntry] ?? [] }
        
        public func availableRooms(for identifier: String? = nil) -> [CytrusRoom] {
            multiplayerObjC.availableRooms(for: identifier)
        }
        
        public func connect(to room: CytrusRoom, with username: String, and password: String? = nil) {
            multiplayerObjC.connect(to: room, with: username, and: password)
        }
        
        public func disconnect() {
            multiplayerObjC.disconnect()
        }
        
        public func sendChatMessage(_ message: String) {
            multiplayerObjC.sendChatMessage(message)
        }
        
        public func updateWebAPIURL() {
            multiplayerObjC.updateWebAPIURL()
        }
        
        public var delegate: (any CytrusMultiplayerManagerDelegate)? {
            get {
                multiplayerObjC.delegate
            }
            set {
                multiplayerObjC.delegate = newValue
            }
        }
        
        /*
        public func chatEntryHandler(_ completionHandler: @escaping (CytrusChatEntry) -> Void) {
            multiplayerObjC.chatEntryHandler = completionHandler
        }
        
        public func errorChangedHandler(_ completionHandler: @escaping (ErrorChange) -> Void) {
            multiplayerObjC.errorChangeHandler = completionHandler
        }
        
        public func stateChangedHandler(_ completionHandler: @escaping (StateChange) -> Void) {
            multiplayerObjC.stateChangeHandler = completionHandler
        }
         */
    }
}

// MARK: CytrusKernelMemoryMode
@objc
public enum CytrusKernelMemoryMode : UInt8 {
    case prod,
         dev1,
         dev2,
         dev3,
         dev4
    
    public var mb: String {
        switch self {
        case .prod:
            "64 MB"
        case .dev1:
            "96 MB"
        case .dev2:
            "80 MB"
        case .dev3:
            "72 MB"
        case .dev4:
            "32 MB"
        @unknown default:
            fatalError()
        }
    }
}

// MARK: CytrusNew3DSKernelMemoryMode
@objc
public enum CytrusNew3DSKernelMemoryMode : UInt8 {
    case legacy,
         prod,
         dev1,
         dev2
    
    public var mb: String {
        switch  self {
        case .legacy:
            "Using legacy KernelMemoryMode"
        case .prod, .dev2:
            "124 MB"
        case .dev1:
            "178 MB"
        @unknown default:
            fatalError()
        }
    }
}

// MARK: CytrusGameInformation
@objcMembers
public class CytrusGameInformation : NSObject {
    public let identifier: UInt64
    public let kernelMemoryMode: CytrusKernelMemoryMode
    public let new3DSKernelMemoryMode: CytrusNew3DSKernelMemoryMode
    public let publisher, regions, title: String
    public let icon: Data?
    
    init(identifier: UInt64, kernelMemoryMode: CytrusKernelMemoryMode, new3DSKernelMemoryMode: CytrusNew3DSKernelMemoryMode,
         publisher: String, regions: String, title: String, icon: Data?) {
        self.identifier = identifier
        self.kernelMemoryMode = kernelMemoryMode
        self.new3DSKernelMemoryMode = new3DSKernelMemoryMode
        self.publisher = publisher
        self.regions = regions
        self.title = title
        self.icon = icon
    }
}

// MARK: CytrusCheat
@objcMembers
public class CytrusCheat : NSObject {
    public var enabled: Bool
    public let code, comments, name, type: String
    
    init(enabled: Bool, code: String, comments: String, name: String, type: String) {
        self.enabled = enabled
        self.code = code
        self.comments = comments
        self.name = name
        self.type = type
    }
}

// MARK: CytrusSaveState
@objcMembers
public class CytrusSaveState : NSObject {
    public let slot: UInt32
    public let status: Int
    public let time: UInt64
    public let name: String
    
    init(slot: UInt32, status: Int, time: UInt64, name: String) {
        self.slot = slot
        self.status = status
        self.time = time
        self.name = name
    }
}
