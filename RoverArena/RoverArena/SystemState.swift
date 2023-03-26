//
//  SystemState.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/22/23.
//

import Foundation
import RoverFramework
import UIKit
import ElementalController

class SystemState {
    
    public static let shared = SystemState()
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    enum VideoSource: Encodable, Decodable {
        case localAR
        case imageFeed
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
            case imageFeed = "Image Feed"
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
        var lastChanged = Date()
        var sourceDevice: SourceDevice = .none
        var sessionIdentifier: String = ""
        var deviceP2PConnectedStatus: DeviceP2PConnectedStatus = .unknown
        var worldMappingStatus: WorldMappingStatus = .notAvailable
        var thermalState = EncodableThermalState(thermalState: .nominal)
        var batteryLevel: Float = UIDevice.current.batteryLevel
        var batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
        var requestedImageFeedSources: [SourceDevice] = []
        var videoSourceDisplaying: VideoSource  = .localAR // UI tracking value

    }
    
    // Used for updating the UI, includes state from all devices including the current device
    // The current device reflected here is coming from onboard rather than the local version
    // so could be slightly stale
    public struct GlobalState: Encodable, Decodable {

        var devicesState: [SourceDevice: DeviceState] = [:]

        init() {
            for sourceDevice in SourceDevice.allCases  {
                devicesState[sourceDevice] = DeviceState()
            }
        }
        
        /*
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
        
        public mutating func storeDeviceState(deviceState: DeviceState) {
            devicesState[deviceState.sourceDevice] = deviceState
        }
         */

    }


    
    var globalState = GlobalState() {
        didSet {
            
            // Update UI here
            
        }
    }
    
    var myDeviceState = DeviceState(sourceDevice: Common.getHostDevice())

    //var localDeviceState: DeviceState = DeviceState()
    
    public func processIncomingDeviceState(data: Data?) {
        
        if let d = data {
            
            // Store the incoming device state
            do {
                let deviceState = try jsonDecoder.decode(DeviceState.self, from: d)
                logDebug("\(Common.getHostDevice()) processing incoming device state from \(deviceState.sourceDevice)")
                globalState.devicesState[deviceState.sourceDevice] = deviceState
                // Send it to all child devices
                if Common.shared.onboardDevice() == Common.getHostDevice() { broadcastStateForDevice(deviceState.sourceDevice) }
            } catch {
                logError("Could not decode state object: \(error)")
            }
        } else {
            fatalError("Failed on nil device state")
        }
    }
    
    // Push the current device's state to onboard
    public func updateOnboardWithDeviceState() {
        logDebug("\(Common.getHostDevice()) updating onboard device with device state")
        let deviceState = globalState.devicesState[Common.getHostDevice()]
        Channels.shared.sendContentTypeToSourceDevice(Common.shared.onboardDevice(), type: Channels.ContentType.state, data: deviceState)
        
    }
    
    // Sub-function used by onboard when pushing changed device states
    // out to other devices
    public func sendDeviceStateForDevice(_ sourceDeviceForState: SourceDevice, to device: SourceDevice) {
        logDebug("\(Common.getHostDevice()) sending state for device \(sourceDeviceForState) to device \(device)")
        let deviceState = globalState.devicesState[sourceDeviceForState]
        Channels.shared.sendContentTypeToSourceDevice(device, type: Channels.ContentType.state, data: deviceState)
        
    }
    
    // Convienance variable that gives all source devices excluding current
    var allOtherDevices: [SourceDevice] {
        
        var allOtherDevices: [SourceDevice] = []
        for sourceDevice in SourceDevice.allCases  {
            if sourceDevice != Common.getHostDevice()  {
                allOtherDevices.append(sourceDevice)
            }
        }
        return allOtherDevices
    }
    
    // Onboard uses this to send updated device state to all devices
    public func broadcastStateForDevice(_ sourceDeviceForState: SourceDevice) {

        if Common.getHostDevice() != Common.shared.onboardDevice() {
            fatalError("Attempt to broadcast device state by non-onboard device")
        }
        logDebug("\(Common.getHostDevice()) broadcasting state for device \(sourceDeviceForState)")
        for destinationSourceDevice in allOtherDevices {
            sendDeviceStateForDevice(sourceDeviceForState, to: destinationSourceDevice)
        }
        
    }
    
    // This can be used by onboard when it wants to blast all devices with
    // the current state of all devices
    public func broadcastAllDeviceStates() {
        
        if Common.getHostDevice() == Common.shared.onboardDevice() {
            fatalError("Attempt to broadcast device state by non-onboard device")
        }
        logDebug("\(Common.getHostDevice()) broadcasting state for all devices to all devices")
        for stateSourceDevice in SourceDevice.allCases {
            for destinationSourceDevice in SourceDevice.allCases {
                if destinationSourceDevice != Common.shared.onboardDevice() {
                    sendDeviceStateForDevice(stateSourceDevice, to: destinationSourceDevice)
                }
            }
        }
        
    }
    
    init() {
        logDebug("Initializing system state for device \(Common.getHostDevice())")
        addObservers()
    }
    
    func addObservers() {

        logDebug("Adding observers for device \(Common.getHostDevice())")
        let _ = NotificationCenter.default.addObserver(
                        forName: ProcessInfo.thermalStateDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.myDeviceState.thermalState = EncodableThermalState(thermalState: ProcessInfo.processInfo.thermalState)
                              Channels.shared.reportDeviceStatusToOnboardDevice()
        }
        
        let _ = NotificationCenter.default.addObserver(
                        forName: UIDevice.batteryLevelDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.myDeviceState.batteryLevel = UIDevice.current.batteryLevel
                              Channels.shared.reportDeviceStatusToOnboardDevice()
        }
        
        let _ = NotificationCenter.default.addObserver(
                        forName: UIDevice.batteryStateDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.myDeviceState.batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
                              Channels.shared.reportDeviceStatusToOnboardDevice()
        }

    }

    func removeObsevers() {
        
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    // List of source devices that have subscribed for an image feed
    public func devicesRequiringImageFeed() -> Set<SourceDevice> {

        let thisSourceDevice = Common.getHostDevice()
        var sourceDevicesRequestingImageFeed = Set<SourceDevice>()
        for sourceDevice in SourceDevice.allCases {
            if sourceDevice != thisSourceDevice {
                let deviceState = globalState.devicesState[sourceDevice]
                if let requestedImageFeeds = deviceState?.requestedImageFeedSources {
                    if requestedImageFeeds.contains(thisSourceDevice) {
                        logDebug("Source device \(sourceDevice) requires image feed from \(Common.getHostDevice())")
                        sourceDevicesRequestingImageFeed.insert(sourceDevice)
                    }
                }
            }
        }
        return sourceDevicesRequestingImageFeed


    }
    
    // Used by any device to know if any other device wants an image feed
    // I don't think is necessary because of the function above
    public var imageFeedRequired: Bool {

        for sourceDevice in SourceDevice.allCases {
            let requestedSources = globalState.devicesState[sourceDevice]?.requestedImageFeedSources
            if let rs = requestedSources {
                if rs.contains(Common.getHostDevice()) { // Finally we're asking if this device has been requested to provide a feed
                    return true
                }
            }
        }
        return false

        //let count = globalState.devicesState.values.filter { $0.imageDisplayEnabled == true }.count

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
