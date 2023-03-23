//
//  SystemState.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/22/23.
//

import Foundation
import RoverFramework
import UIKit

class SystemState {
    
    public static let shared = SystemState()
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    enum VideoSource: Encodable, Decodable {
        case localAR
        case onboardSource
    }
    
    public enum DeviceP2PConnectedStatus: String, Encodable, Decodable {
        case unknown = "Unknown"
        case disconnected = "Disconnected"
        case waiting = "Waiting To Participate"
        case connected = "Connected"
        case joined = "Joined"
    }
    
    public enum DeviceARStatus: String, Encodable, Decodable {
        case disconnected = "Disconnected"
        case waiting = "Waiting To Participate"
        case connected = "Connected"
        case joined = "Joined"
    }

    enum ChannelStatus: String, Encodable, Decodable {
        case offline = "Offline"
        case connected = "Connected"
    }
    
    enum WorldMappingStatus: String, Encodable, Decodable {
        case mapped = "Mapped"
        case notAvailable = "Not Available"
        case extending = "Extending"
        case limited = "Limited"
    }
    
    struct Display: Codable {
        
        enum Mode: String, Encodable, Decodable {
            case arview = "AR View"
            case imageView = "Imageview"
        }
        
        init(mode: Mode) {
            self.mode = mode
        }
        
        // Decoding init function
        init(from decoder: Decoder) throws {
            
            let values = try decoder.container(keyedBy: CodingKeys.self)
            mode = try values.decode(Mode.self, forKey: .mode)
             
        }
        
        //var imageViewSourceDevice = SourceDevice.onboardDevice
        
        var mode: Mode?
        
        /*
        // Decoding init function
        init(from decoder: Decoder) throws {
            /*
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: .name)
            age = try values.decode(Int.self, forKey: .age)
            address = try values.decode(String.self, forKey: .address)
             */
        }
        */
        
        /*
        // Encoding init function
        init(name: String, age: Int, address: String) {
            self.name = name
            self.age = age
            self.address = address
        }
        */
        
        // CodingKeys
        enum CodingKeys: String, CodingKey {
            case mode
        }
   
    }

    struct DeviceState: Encodable, Decodable {
        //let statusMappingToString: [ARFrame.WorldMappingStatus: String] = [.notAvailable: "Not Available", .limited: "Limited", .extending: "Extending", .mapped: "Mapped"]
        var sourceDevice: SourceDevice = .none
        var sessionIdentifier: String = ""
        var videoSourceDisplaying: VideoSource  = .localAR // UI tracking value
        var deviceConnectedStatus: DeviceP2PConnectedStatus = .unknown
        var imageDisplayEnabled: Bool = false
        var worldMappingStatus: WorldMappingStatus = .notAvailable
        var thermalState = EncodableThermalState(thermalState: .nominal)
        var batteryLevel: Float = UIDevice.current.batteryLevel
        var batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
        
    }
    
    public struct WorldState: Encodable, Decodable {

        var devicesState: [SourceDevice: DeviceState] = [.iPhone12Pro: DeviceState(), .iPadPro12: DeviceState(), .iPhone14ProMax: DeviceState(), .iPhoneXSMax: DeviceState()]

        init() {
            for sourceDevice in SourceDevice.allCases  {
                devicesState[sourceDevice] = DeviceState()
            }
        }
        
        public var myState: DeviceState? {
            get {
                if let ds = devicesState[Common.getHostDevice()]{
                    return ds
                } else {
                    return nil
                }
            }
            set {
                devicesState[Common.getHostDevice()] = newValue
            }
        }

    }

    
    var worldState = WorldState() {
        didSet {
            
            // Update UI here
            
        }
    }

    var localDeviceState: DeviceState = DeviceState(imageDisplayEnabled: false)
    
    func addObservers() {

        let _ = NotificationCenter.default.addObserver(
                        forName: ProcessInfo.thermalStateDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.localDeviceState.thermalState = EncodableThermalState(thermalState: ProcessInfo.processInfo.thermalState)
                              Channels.shared.reportDeviceStatusToOnboardDevice()
        }
        
        let _ = NotificationCenter.default.addObserver(
                        forName: UIDevice.batteryLevelDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.localDeviceState.batteryLevel = UIDevice.current.batteryLevel
                              Channels.shared.reportDeviceStatusToOnboardDevice()
        }
        
        let _ = NotificationCenter.default.addObserver(
                        forName: UIDevice.batteryStateDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.localDeviceState.batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
                              Channels.shared.reportDeviceStatusToOnboardDevice()
        }

    }

    func removeObsevers() {
        
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    
    public var imageFeedRequired: Bool {
        let count = worldState.devicesState.values.filter { $0.imageDisplayEnabled == true }.count
        if count > 0 {
            return true
        } else {
            return false
        }
    }

    
    struct EncodableThermalState: Codable {
        let thermalState: ProcessInfo.ThermalState

        enum CodingKeys: String, CodingKey {
            case thermalState
        }

        init(thermalState: ProcessInfo.ThermalState) {
            self.thermalState = thermalState
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawValue = try container.decode(Int.self, forKey: .thermalState)
            
            if let state = ProcessInfo.ThermalState(rawValue: rawValue) {
                self.thermalState = state
            } else {
                throw DecodingError.dataCorruptedError(forKey: .thermalState, in: container, debugDescription: "Invalid thermal state raw value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(thermalState.rawValue, forKey: .thermalState)
        }
    }
    
    struct EncodableBatteryState: Codable {
        
        var batteryState = UIDevice.current.batteryState

        enum CodingKeys: String, CodingKey {
            case batteryState
        }

        init(batteryState: UIDevice.BatteryState) {
            self.batteryState = batteryState
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawValue = try container.decode(Int.self, forKey: .batteryState)
            
            if let state = UIDevice.BatteryState(rawValue: rawValue) {
                self.batteryState = state
            } else {
                throw DecodingError.dataCorruptedError(forKey: .batteryState, in: container, debugDescription: "Invalid battery  state raw value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(batteryState.rawValue, forKey: .batteryState)
        }
    }

    
}
