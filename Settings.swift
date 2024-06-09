//
//  Settings.swift
//  Cytrus
//
//  Created by Jarrod Norwell on 4/6/2024.
//

import Foundation

public struct CytrusSettings {
    
}

extension CytrusSettings {
    public enum Keys : String {
        case cpuClockPercentage = "cytrus.cpuClockPercentage"
        case useNew3DS = "cytrus.useNew3DS"
        case useLLEApplets = "cytrus.useLLEApplets"
        
        case regionSelect = "cytrus.regionSelect"
        
        case useSpirvShaderGeneration = "cytrus.spirvShaderGeneration"
        case useAsyncShaderCompilation = "cytrus.useAsyncShaderCompilation"
        case useAsyncPresentation = "cytrus.useAsyncPresentation"
        case useHardwareShaders = "cytrus.useHardwareShaders"
        case useDiskShaderCache = "cytrus.useDiskShaderCache"
        case useShadersAccurateMul = "cytrus.useShadersAccurateMul"
        case useNewVSync = "cytrus.useNewVSync"
        case useShaderJIT = "cytrus.useShaderJIT"
        case resolutionFactor = "cytrus.resolutionFactor"
        case textureFilter = "cytrus.textureFilter"
        case textureSampling = "cytrus.textureSampling"
        
        case layoutOption = "cytrus.layoutOption"
        
        case render3D = "cytrus.render3D"
        case monoRender = "cytrus.monoRender"
        
        case useCustomTextures = "cytrus.useCustomTextures"
        case preloadTextures = "cytrus.preloadTextures"
        case asyncCustomLoading = "cytrus.asyncCustomLoading"
        
        case audioEmulation = "cytrus.audioEmulation"
        case audioStretching = "cytrus.audioStretching"
        case audioOutputDevice = "cytrus.audioOutputDevice"
        case audioInputDevice = "cytrus.audioInputDevice"
        
        case useCustomLayout = "cytrus.useCustomLayout"
        case customLayoutTopLeft = "cytrus.customLayoutTopLeft"
        case customLayoutTopTop = "cytrus.customLayoutTopTop"
        case customLayoutTopRight = "cytrus.customLayoutTopRight"
        case customLayoutTopBottom = "cytrus.customLayoutTopBottom"
        case customLayoutBottomLeft = "cytrus.customLayoutBottomLeft"
        case customLayoutBottomTop = "cytrus.customLayoutBottomTop"
        case customLayoutBottomRight = "cytrus.customLayoutBottomRight"
        case customLayoutBottomBottom = "cytrus.customLayoutBottomBottom"
    }

    @objc public class Settings : NSObject {
        public static var cpuClockPercentage: Int = UserDefaults.standard.integer(forKey: Keys.cpuClockPercentage.rawValue)
        public static var useNew3DS: Bool = UserDefaults.standard.bool(forKey: Keys.useNew3DS.rawValue)
        public static var useLLEApplets: Bool = UserDefaults.standard.bool(forKey: Keys.useLLEApplets.rawValue)
        
        public static var regionSelect: Int = UserDefaults.standard.integer(forKey: Keys.regionSelect.rawValue)
        
        public static var useSpirvShaderGeneration: Bool = UserDefaults.standard.bool(forKey: Keys.useSpirvShaderGeneration.rawValue)
        public static var useAsyncShaderCompilation: Bool = UserDefaults.standard.bool(forKey: Keys.useAsyncShaderCompilation.rawValue)
        public static var useAsyncPresentation: Bool = UserDefaults.standard.bool(forKey: Keys.useAsyncPresentation.rawValue)
        public static var useHardwareShaders: Bool = UserDefaults.standard.bool(forKey: Keys.useHardwareShaders.rawValue)
        public static var useDiskShaderCache: Bool = UserDefaults.standard.bool(forKey: Keys.useDiskShaderCache.rawValue)
        public static var useShadersAccurateMul: Bool = UserDefaults.standard.bool(forKey: Keys.useShadersAccurateMul.rawValue)
        public static var useNewVSync: Bool = UserDefaults.standard.bool(forKey: Keys.useNewVSync.rawValue)
        public static var useShaderJIT: Bool = UserDefaults.standard.bool(forKey: Keys.useShaderJIT.rawValue)
        public static var resolutionFactor: Int = UserDefaults.standard.integer(forKey: Keys.resolutionFactor.rawValue)
        public static var textureFilter: Int = UserDefaults.standard.integer(forKey: Keys.textureFilter.rawValue)
        public static var textureSampling: Int = UserDefaults.standard.integer(forKey: Keys.textureSampling.rawValue)
        
        public static var layoutOption: Int = UserDefaults.standard.integer(forKey: Keys.layoutOption.rawValue)
        
        public static var render3D: Int = UserDefaults.standard.integer(forKey: Keys.render3D.rawValue)
        public static var monoRender: Int = UserDefaults.standard.integer(forKey: Keys.monoRender.rawValue)
        
        public static var useCustomTextures: Bool = UserDefaults.standard.bool(forKey: Keys.useCustomTextures.rawValue)
        public static var preloadTextures: Bool = UserDefaults.standard.bool(forKey: Keys.preloadTextures.rawValue)
        public static var asyncCustomLoading: Bool = UserDefaults.standard.bool(forKey: Keys.asyncCustomLoading.rawValue)
        
        public static var audioEmulation: Int = UserDefaults.standard.integer(forKey: Keys.audioEmulation.rawValue)
        public static var audioStretching: Bool = UserDefaults.standard.bool(forKey: Keys.audioStretching.rawValue)
        public static var audioOutputDevice: Int = UserDefaults.standard.integer(forKey: Keys.audioOutputDevice.rawValue)
        public static var audioInputDevice: Int = UserDefaults.standard.integer(forKey: Keys.audioInputDevice.rawValue)
        
        public static var useCustomLayout: Bool = UserDefaults.standard.bool(forKey: Keys.useCustomLayout.rawValue)
        public static var customLayoutTopLeft: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutTopLeft.rawValue)
        public static var customLayoutTopTop: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutTopTop.rawValue)
        public static var customLayoutTopRight: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutTopRight.rawValue)
        public static var customLayoutTopBottom: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutTopBottom.rawValue)
        public static var customLayoutBottomLeft: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomLeft.rawValue)
        public static var customLayoutBottomTop: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomTop.rawValue)
        public static var customLayoutBottomRight: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomRight.rawValue)
        public static var customLayoutBottomBottom: Int = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomBottom.rawValue)
        
        public static var shared = Settings()
        
        public func get(for key: Keys) -> Bool {
            switch key {
            case .useNew3DS:
                Settings.useNew3DS
            case .useLLEApplets:
                Settings.useLLEApplets
            case .useSpirvShaderGeneration:
                Settings.useSpirvShaderGeneration
            case .useAsyncShaderCompilation:
                Settings.useAsyncShaderCompilation
            case .useAsyncPresentation:
                Settings.useAsyncPresentation
            case .useHardwareShaders:
                Settings.useHardwareShaders
            case .useDiskShaderCache:
                Settings.useDiskShaderCache
            case .useShadersAccurateMul:
                Settings.useShadersAccurateMul
            case .useNewVSync:
                Settings.useNewVSync
            case .useShaderJIT:
                Settings.useShaderJIT
            case .useCustomTextures:
                Settings.useCustomTextures
            case .preloadTextures:
                Settings.preloadTextures
            case .asyncCustomLoading:
                Settings.asyncCustomLoading
            case .audioStretching:
                Settings.audioStretching
            case .useCustomLayout:
                Settings.useCustomLayout
            default:
                false
            }
        }
        
        public func set(_ bool: Bool, for key: Keys) {
            UserDefaults.standard.set(bool, forKey: key.rawValue)
            switch key {
            case .useNew3DS:
                Settings.useNew3DS = bool
            case .useLLEApplets:
                Settings.useLLEApplets = bool
            case .useSpirvShaderGeneration:
                Settings.useSpirvShaderGeneration = bool
            case .useAsyncShaderCompilation:
                Settings.useAsyncShaderCompilation = bool
            case .useAsyncPresentation:
                Settings.useAsyncPresentation = bool
            case .useHardwareShaders:
                Settings.useHardwareShaders = bool
            case .useDiskShaderCache:
                Settings.useDiskShaderCache = bool
            case .useShadersAccurateMul:
                Settings.useShadersAccurateMul = bool
            case .useNewVSync:
                Settings.useNewVSync = bool
            case .useShaderJIT:
                Settings.useShaderJIT = bool
            case .useCustomTextures:
                Settings.useCustomTextures = bool
            case .preloadTextures:
                Settings.preloadTextures = bool
            case .asyncCustomLoading:
                Settings.asyncCustomLoading = bool
            case .audioStretching:
                Settings.audioStretching = bool
            case .useCustomLayout:
                Settings.useCustomLayout = bool
            default:
                break
            }
            
            updateSettings()
        }
        
        public func get(for key: Keys) -> Int {
            switch key {
            case .cpuClockPercentage:
                Settings.cpuClockPercentage
            case .regionSelect:
                Settings.regionSelect
            case .resolutionFactor:
                Settings.resolutionFactor
            case .textureFilter:
                Settings.textureFilter
            case .textureSampling:
                Settings.textureSampling
            case .layoutOption:
                Settings.layoutOption
            case .render3D:
                Settings.render3D
            case .monoRender:
                Settings.monoRender
            case .audioEmulation:
                Settings.audioEmulation
            case .audioOutputDevice:
                Settings.audioOutputDevice
            case .audioInputDevice:
                Settings.audioInputDevice
            case .customLayoutTopLeft:
                Settings.customLayoutTopLeft
            case .customLayoutTopTop:
                Settings.customLayoutTopTop
            case .customLayoutTopRight:
                Settings.customLayoutTopRight
            case .customLayoutTopBottom:
                Settings.customLayoutTopBottom
            case .customLayoutBottomLeft:
                Settings.customLayoutBottomLeft
            case .customLayoutBottomTop:
                Settings.customLayoutBottomTop
            case .customLayoutBottomRight:
                Settings.customLayoutBottomRight
            case .customLayoutBottomBottom:
                Settings.customLayoutBottomBottom
            default:
                -1
            }
        }
        
        public func set(_ int: Int, for key: Keys) {
            UserDefaults.standard.set(int, forKey: key.rawValue)
            switch key {
            case .cpuClockPercentage:
                Settings.cpuClockPercentage = int
            case .regionSelect:
                Settings.regionSelect = int
            case .resolutionFactor:
                Settings.resolutionFactor = int
            case .textureFilter:
                Settings.textureFilter = int
            case .textureSampling:
                Settings.textureSampling = int
            case .layoutOption:
                Settings.layoutOption = int
            case .render3D:
                Settings.render3D = int
            case .monoRender:
                Settings.monoRender = int
            case .audioEmulation:
                Settings.audioEmulation = int
            case .audioOutputDevice:
                Settings.audioOutputDevice = int
            case .audioInputDevice:
                Settings.audioInputDevice = int
            case .customLayoutTopLeft:
                Settings.customLayoutTopLeft = int
            case .customLayoutTopTop:
                Settings.customLayoutTopTop = int
            case .customLayoutTopRight:
                Settings.customLayoutTopRight = int
            case .customLayoutTopBottom:
                Settings.customLayoutTopBottom = int
            case .customLayoutBottomLeft:
                Settings.customLayoutBottomLeft = int
            case .customLayoutBottomTop:
                Settings.customLayoutBottomTop = int
            case .customLayoutBottomRight:
                Settings.customLayoutBottomRight = int
            case .customLayoutBottomBottom:
                Settings.customLayoutBottomBottom = int
            default:
                break
            }
            
            updateSettings()
        }
        
        public func setDefaultSettingsIfNeeded() {
            if !UserDefaults.standard.bool(forKey: "cytrus.hasSetDefaultSettings") {
                UserDefaults.standard.set(100, forKey: Keys.cpuClockPercentage.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.useNew3DS.rawValue)
                UserDefaults.standard.set(false, forKey: Keys.useLLEApplets.rawValue)
                
                UserDefaults.standard.set(-1, forKey: Keys.regionSelect.rawValue)
                
                UserDefaults.standard.set(true, forKey: Keys.useSpirvShaderGeneration.rawValue)
                UserDefaults.standard.set(false, forKey: Keys.useAsyncShaderCompilation.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.useAsyncPresentation.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.useHardwareShaders.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.useDiskShaderCache.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.useShadersAccurateMul.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.useNewVSync.rawValue)
                UserDefaults.standard.set(1, forKey: Keys.resolutionFactor.rawValue)
                UserDefaults.standard.set(false, forKey: Keys.useShaderJIT.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.textureFilter.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.textureSampling.rawValue)
                
                UserDefaults.standard.set(0, forKey: Keys.layoutOption.rawValue)
                
                UserDefaults.standard.set(0, forKey: Keys.render3D.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.monoRender.rawValue)
                
                UserDefaults.standard.set(false, forKey: Keys.useCustomTextures.rawValue)
                UserDefaults.standard.set(false, forKey: Keys.preloadTextures.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.asyncCustomLoading.rawValue)
                
                UserDefaults.standard.set(0, forKey: Keys.audioEmulation.rawValue)
                UserDefaults.standard.set(true, forKey: Keys.audioStretching.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.audioOutputDevice.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.audioInputDevice.rawValue)
                
                UserDefaults.standard.set(false, forKey: Keys.useCustomLayout.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.customLayoutTopLeft.rawValue)
                UserDefaults.standard.set(0, forKey: Keys.customLayoutTopBottom.rawValue)
                UserDefaults.standard.set(480, forKey: Keys.customLayoutTopRight.rawValue)
                UserDefaults.standard.set(240, forKey: Keys.customLayoutTopBottom.rawValue)
                UserDefaults.standard.set(40, forKey: Keys.customLayoutBottomLeft.rawValue)
                UserDefaults.standard.set(240, forKey: Keys.customLayoutBottomTop.rawValue)
                UserDefaults.standard.set(360, forKey: Keys.customLayoutBottomRight.rawValue)
                UserDefaults.standard.set(480, forKey: Keys.customLayoutBottomBottom.rawValue)
                
                UserDefaults.standard.set(true, forKey: "cytrus.hasSetDefaultSettings")
            }
        }
        
        public func resetSettings() {
            UserDefaults.standard.set(false, forKey: "cytrus.hasSetDefaultSettings")
            setDefaultSettingsIfNeeded()
            
            Settings.cpuClockPercentage = UserDefaults.standard.integer(forKey: Keys.cpuClockPercentage.rawValue)
            Settings.useNew3DS = UserDefaults.standard.bool(forKey: Keys.useNew3DS.rawValue)
            Settings.useLLEApplets = UserDefaults.standard.bool(forKey: Keys.useLLEApplets.rawValue)
            
            Settings.regionSelect = UserDefaults.standard.integer(forKey: Keys.regionSelect.rawValue)
            
            Settings.useSpirvShaderGeneration = UserDefaults.standard.bool(forKey: Keys.useSpirvShaderGeneration.rawValue)
            Settings.useAsyncShaderCompilation = UserDefaults.standard.bool(forKey: Keys.useAsyncShaderCompilation.rawValue)
            Settings.useAsyncPresentation = UserDefaults.standard.bool(forKey: Keys.useAsyncPresentation.rawValue)
            Settings.useHardwareShaders = UserDefaults.standard.bool(forKey: Keys.useHardwareShaders.rawValue)
            Settings.useDiskShaderCache = UserDefaults.standard.bool(forKey: Keys.useDiskShaderCache.rawValue)
            Settings.useShadersAccurateMul = UserDefaults.standard.bool(forKey: Keys.useShadersAccurateMul.rawValue)
            Settings.useNewVSync = UserDefaults.standard.bool(forKey: Keys.useNewVSync.rawValue)
            Settings.useShaderJIT = UserDefaults.standard.bool(forKey: Keys.useShaderJIT.rawValue)
            Settings.resolutionFactor = UserDefaults.standard.integer(forKey: Keys.resolutionFactor.rawValue)
            Settings.textureFilter = UserDefaults.standard.integer(forKey: Keys.textureFilter.rawValue)
            Settings.textureSampling = UserDefaults.standard.integer(forKey: Keys.textureSampling.rawValue)
            
            Settings.layoutOption = UserDefaults.standard.integer(forKey: Keys.layoutOption.rawValue)
            
            Settings.render3D = UserDefaults.standard.integer(forKey: Keys.render3D.rawValue)
            Settings.monoRender = UserDefaults.standard.integer(forKey: Keys.monoRender.rawValue)
            
            Settings.useCustomTextures = UserDefaults.standard.bool(forKey: Keys.useCustomTextures.rawValue)
            Settings.preloadTextures = UserDefaults.standard.bool(forKey: Keys.preloadTextures.rawValue)
            Settings.asyncCustomLoading = UserDefaults.standard.bool(forKey: Keys.asyncCustomLoading.rawValue)
            
            Settings.audioEmulation = UserDefaults.standard.integer(forKey: Keys.audioEmulation.rawValue)
            Settings.audioStretching = UserDefaults.standard.bool(forKey: Keys.audioStretching.rawValue)
            Settings.audioOutputDevice = UserDefaults.standard.integer(forKey: Keys.audioOutputDevice.rawValue)
            Settings.audioInputDevice = UserDefaults.standard.integer(forKey: Keys.audioInputDevice.rawValue)
            
            Settings.useCustomLayout = UserDefaults.standard.bool(forKey: Keys.useCustomLayout.rawValue)
            Settings.customLayoutTopLeft = UserDefaults.standard.integer(forKey: Keys.customLayoutTopLeft.rawValue)
            Settings.customLayoutTopTop = UserDefaults.standard.integer(forKey: Keys.customLayoutTopTop.rawValue)
            Settings.customLayoutTopRight = UserDefaults.standard.integer(forKey: Keys.customLayoutTopRight.rawValue)
            Settings.customLayoutTopBottom = UserDefaults.standard.integer(forKey: Keys.customLayoutTopBottom.rawValue)
            Settings.customLayoutBottomLeft = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomLeft.rawValue)
            Settings.customLayoutBottomTop = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomTop.rawValue)
            Settings.customLayoutBottomRight = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomRight.rawValue)
            Settings.customLayoutBottomBottom = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomBottom.rawValue)
        }
        
        fileprivate func updateSettings() {
            Settings.cpuClockPercentage = UserDefaults.standard.integer(forKey: Keys.cpuClockPercentage.rawValue)
            Settings.useNew3DS = UserDefaults.standard.bool(forKey: Keys.useNew3DS.rawValue)
            Settings.useLLEApplets = UserDefaults.standard.bool(forKey: Keys.useLLEApplets.rawValue)
            
            Settings.regionSelect = UserDefaults.standard.integer(forKey: Keys.regionSelect.rawValue)
            
            Settings.useSpirvShaderGeneration = UserDefaults.standard.bool(forKey: Keys.useSpirvShaderGeneration.rawValue)
            Settings.useAsyncShaderCompilation = UserDefaults.standard.bool(forKey: Keys.useAsyncShaderCompilation.rawValue)
            Settings.useAsyncPresentation = UserDefaults.standard.bool(forKey: Keys.useAsyncPresentation.rawValue)
            Settings.useHardwareShaders = UserDefaults.standard.bool(forKey: Keys.useHardwareShaders.rawValue)
            Settings.useDiskShaderCache = UserDefaults.standard.bool(forKey: Keys.useDiskShaderCache.rawValue)
            Settings.useShadersAccurateMul = UserDefaults.standard.bool(forKey: Keys.useShadersAccurateMul.rawValue)
            Settings.useNewVSync = UserDefaults.standard.bool(forKey: Keys.useNewVSync.rawValue)
            Settings.useShaderJIT = UserDefaults.standard.bool(forKey: Keys.useShaderJIT.rawValue)
            Settings.resolutionFactor = UserDefaults.standard.integer(forKey: Keys.resolutionFactor.rawValue)
            Settings.textureFilter = UserDefaults.standard.integer(forKey: Keys.textureFilter.rawValue)
            Settings.textureSampling = UserDefaults.standard.integer(forKey: Keys.textureSampling.rawValue)
            
            Settings.layoutOption = UserDefaults.standard.integer(forKey: Keys.layoutOption.rawValue)
            
            Settings.render3D = UserDefaults.standard.integer(forKey: Keys.render3D.rawValue)
            Settings.monoRender = UserDefaults.standard.integer(forKey: Keys.monoRender.rawValue)
            
            Settings.useCustomTextures = UserDefaults.standard.bool(forKey: Keys.useCustomTextures.rawValue)
            Settings.preloadTextures = UserDefaults.standard.bool(forKey: Keys.preloadTextures.rawValue)
            Settings.asyncCustomLoading = UserDefaults.standard.bool(forKey: Keys.asyncCustomLoading.rawValue)
            
            Settings.audioEmulation = UserDefaults.standard.integer(forKey: Keys.audioEmulation.rawValue)
            Settings.audioStretching = UserDefaults.standard.bool(forKey: Keys.audioStretching.rawValue)
            Settings.audioOutputDevice = UserDefaults.standard.integer(forKey: Keys.audioOutputDevice.rawValue)
            Settings.audioInputDevice = UserDefaults.standard.integer(forKey: Keys.audioInputDevice.rawValue)
            
            Settings.useCustomLayout = UserDefaults.standard.bool(forKey: Keys.useCustomLayout.rawValue)
            Settings.customLayoutTopLeft = UserDefaults.standard.integer(forKey: Keys.customLayoutTopLeft.rawValue)
            Settings.customLayoutTopTop = UserDefaults.standard.integer(forKey: Keys.customLayoutTopTop.rawValue)
            Settings.customLayoutTopRight = UserDefaults.standard.integer(forKey: Keys.customLayoutTopRight.rawValue)
            Settings.customLayoutTopBottom = UserDefaults.standard.integer(forKey: Keys.customLayoutTopBottom.rawValue)
            Settings.customLayoutBottomLeft = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomLeft.rawValue)
            Settings.customLayoutBottomTop = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomTop.rawValue)
            Settings.customLayoutBottomRight = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomRight.rawValue)
            Settings.customLayoutBottomBottom = UserDefaults.standard.integer(forKey: Keys.customLayoutBottomBottom.rawValue)
            
            Cytrus.shared.updateSettings()
        }
    }
}
