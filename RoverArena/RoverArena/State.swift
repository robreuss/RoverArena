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
import Combine
import ARKit

class State: ObservableObject {
    
    public static let shared = State()
    
    init() {
        logDebug("Initializing system state for device \(Common.currentDevice())")
        
        for sourceDevice in SourceDevice.allCases  {
            devicesState[sourceDevice] = DeviceState()
        }
        addObservers()
        
        cancellable = $devicesState.sink { newValue in
            /*
            if self.currentDeviceState.channelStatus != .disconnected {
                if Common.isHub() {
                    self.broadcastStateForDevice(Common.currentDevice())
                } else {
                    Channels.shared.reportDeviceStatusToHubDevice()
                }
            }
             */
        }

    }

    var cancellable: Cancellable?
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    enum VideoSource: Encodable, Decodable {
        case localAR
        case imageFeed
    }
    
    public enum DeviceP2PConnectedStatus: String, Encodable, Decodable {
        case unknown = "Unknown"
        case disconnected = "Disconnected"
        case waiting = "Waiting"
        case connected = "Connected"
        case joined = "Joined"
    }
    
    public enum DeviceARStatus: String, Encodable, Decodable {
        case disconnected = "Disconnected"
        case waiting = "Waiting To Participate"
        case connected = "Connected"
        case joined = "Joined"
    }
    
    /*
    enum WorldMappingStatus: String, Encodable, Decodable {
        case mapped = "Mapped"
        case notAvailable = "Not Available"
        case extending = "Extending"
        case limited = "Limited"
    }
    */
    enum ChannelStatus: String, Encodable, Decodable {
        case disconnected = "~"
        case hub = "Hub"
        case controller = "Controller"
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
        
        var mode: Mode?

        // CodingKeys
        enum CodingKeys: String, CodingKey {
            case mode
        }
   
    }

    enum ARMode: String, Encodable, Decodable {
        case none = "~"
        case full = "Full"
        case positional = "Positional"
        case paused = "Paused"
    }

    struct DeviceState: Encodable, Decodable, Equatable {
        //let statusMappingToString: [ARFrame.WorldMappingStatus: String] = [.notAvailable: "Not Available", .limited: "Limited", .extending: "Extending", .mapped: "Mapped"]

        var launchDate: Date?
        
        var refreshUI = true
        
        var sourceDevice: SourceDevice = .none
        var sessionIdentifier: String = ""
        var deviceP2PConnectedStatus: DeviceP2PConnectedStatus = .unknown
        //var worldMappingStatus: WorldMappingStatus = .notAvailable
        var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
        var arMode: ARMode = .none
        var arWorldMap = Data()
        
        var thermalState = EncodableThermalState(thermalState: .nominal)
        var batteryLevel: Float = 0.0
        var batteryState = EncodableBatteryState(batteryState: .unknown)
        
        var activeImageFeeds = 0
        var requestedImageFeedSources: [SourceDevice] = []
        var videoSourceDisplaying: VideoSource  = .localAR // UI tracking value
        
        var fps: Float = 0.0
        
        var channelStatus: ChannelStatus = .disconnected

        static func ==(lhs: DeviceState, rhs: DeviceState) -> Bool {
            return lhs.sourceDevice == rhs.sourceDevice &&
            lhs.sessionIdentifier == rhs.sessionIdentifier &&
            lhs.deviceP2PConnectedStatus == rhs.deviceP2PConnectedStatus &&
            lhs.worldMappingStatus == rhs.worldMappingStatus &&
            lhs.thermalState == rhs.thermalState &&
            lhs.batteryLevel == rhs.batteryLevel &&
            lhs.batteryState == rhs.batteryState &&
            lhs.activeImageFeeds == rhs.activeImageFeeds &&
            lhs.requestedImageFeedSources == rhs.requestedImageFeedSources &&
            lhs.channelStatus == rhs.channelStatus
        }
        
        init(sourceDevice: SourceDevice? = SourceDevice.none) {
            if let sd = sourceDevice {
                logDebug("Initializing device state for: \(sd)")
                self.sourceDevice = sd
                /*
                if Common.isHub(sourceDevice: sd) {
                    requestedImageFeedSources = [.iPhone12Pro, .iPhone14ProMax]
                }
                 */
                if sd.isCurrentDevice() {
                    launchDate = Date()
                    batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
                    thermalState = EncodableThermalState(thermalState: ProcessInfo.processInfo.thermalState)

                    
                }
            }
        }
    }
    
    var launchBrightness = UIScreen.main.brightness
    var operationalBrightness = UIScreen.main.brightness {
        didSet {
            UIScreen.main.brightness = operationalBrightness
        }
    }

    var lastSentDeviceState = DeviceState()
    @Published var devicesState: [SourceDevice: DeviceState] = [:]
    @Published var currentDeviceState = DeviceState(sourceDevice: Common.currentDevice()) {
        didSet {

                if Common.isHub() {
                    Channels.shared.broadcastHubDeviceStateToAllDevices()
                } else {
                    Channels.shared.reportDeviceStatusToHubDevice()
                }
                lastSentDeviceState = currentDeviceState
            
            if UIDevice.current.isBatteryMonitoringEnabled == false {
                UIDevice.current.isBatteryMonitoringEnabled = true
                usleep(500000)
                currentDeviceState.batteryLevel = UIDevice.current.batteryLevel
                currentDeviceState.batteryState.batteryState = UIDevice.current.batteryState
            }

            devicesState[currentDeviceState.sourceDevice] = currentDeviceState

        }
    }
  
    public func resetCurrentDeviceState() {
        currentDeviceState = DeviceState(sourceDevice: Common.currentDevice())
    }

    public func processIncomingDeviceState(data: Data?) {
        
        if let d = data {
            
            // Store the incoming device state
            do {
                let deviceState = try jsonDecoder.decode(DeviceState.self, from: d)
                logVerbose("\(Common.currentDevice()) processing incoming device state from \(deviceState.sourceDevice)")
                devicesState[deviceState.sourceDevice] = deviceState
                // Send it to all child devices
                if Common.shared.hubDevice() == Common.currentDevice() { broadcastStateForDevice(deviceState.sourceDevice) }
            } catch {
                logError("Could not decode state object: \(error)")
            }
        } else {
            fatalError("Failed on nil device state")
        }
    }
    
    // Push the current device's state to hub
    public func updateHubWithDeviceState() {
        logVerbose("\(Common.currentDevice()) updating hub device with device state")
        let deviceState = devicesState[Common.currentDevice()]
        Channels.shared.sendContentTypeToSourceDevice(Common.shared.hubDevice(), toServer: true, type: Channels.ContentType.state, data: deviceState)
        
    }
    
    // Sub-function used by hub when pushing changed device states
    // out to other devices
    public func sendDeviceStateForDevice(_ sourceDeviceForState: SourceDevice, to device: SourceDevice) {
        logVerbose("\(Common.currentDevice()) sending state for device \(sourceDeviceForState) to device \(device)")
        let deviceState = devicesState[sourceDeviceForState]
        Channels.shared.sendContentTypeToSourceDevice(device, toServer: false, type: Channels.ContentType.state, data: deviceState)
        
    }
    
    // Convienance variable that gives all source devices excluding current
    var allOtherDevices: [SourceDevice] {
        
        var allOtherDevices: [SourceDevice] = []
        for sourceDevice in SourceDevice.allCases  {
            if !sourceDevice.isCurrentDevice() {
                allOtherDevices.append(sourceDevice)
            }
        }
        return allOtherDevices
    }
    
    // Hub uses this to send updated device state to all devices
    public func broadcastStateForDevice(_ sourceDeviceForState: SourceDevice) {

        if Common.currentDevice() != Common.shared.hubDevice() {
            fatalError("Attempt to broadcast device state by non-hub device")
        }
        logVerbose("\(Common.currentDevice()) broadcasting state for device \(sourceDeviceForState)")
        for destinationSourceDevice in allOtherDevices {
            sendDeviceStateForDevice(sourceDeviceForState, to: destinationSourceDevice)
        }
        
    }
    
    // This can be used by hub when it wants to blast all devices with
    // the current state of all devices
    public func broadcastAllDeviceStates() {
        
        if Common.currentDevice() == Common.shared.hubDevice() {
            fatalError("Attempt to broadcast device state by non-hub device")
        }
        logVerbose("\(Common.currentDevice()) broadcasting state for all devices to all devices")
        for stateSourceDevice in SourceDevice.allCases {
            for destinationSourceDevice in SourceDevice.allCases {
                if destinationSourceDevice != Common.shared.hubDevice() {
                    sendDeviceStateForDevice(stateSourceDevice, to: destinationSourceDevice)
                }
            }
        }
        
    }

    func addObservers() {

        logDebug("Adding observers for device \(Common.currentDevice())")
        let _ = NotificationCenter.default.addObserver(
                        forName: ProcessInfo.thermalStateDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.currentDeviceState.thermalState = EncodableThermalState(thermalState: ProcessInfo.processInfo.thermalState)
                              //Channels.shared.reportDeviceStatusToHubDevice()
        }
        
        let _ = NotificationCenter.default.addObserver(
                        forName: UIDevice.batteryLevelDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.currentDeviceState.batteryLevel = UIDevice.current.batteryLevel
        }
        
        let _ = NotificationCenter.default.addObserver(
                        forName: UIDevice.batteryStateDidChangeNotification,
                         object: nil,
                          queue: nil) { notification in
                              self.currentDeviceState.batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
        }

    }

    func removeObsevers() {
        
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    // List of source devices that have subscribed for an image feed
    public func devicesRequiringImageFeed() -> Set<SourceDevice> {

        let thisSourceDevice = Common.currentDevice()
        var sourceDevicesRequestingImageFeed = Set<SourceDevice>()
        for sourceDevice in SourceDevice.allCases {
            if sourceDevice != thisSourceDevice {
                let deviceState = devicesState[sourceDevice]
                if let requestedImageFeeds = deviceState?.requestedImageFeedSources {
                    if requestedImageFeeds.contains(thisSourceDevice) {
                        //logDebug("Source device \(sourceDevice) requires image feed from \(Common.getHostDevice())")
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
            let requestedSources = devicesState[sourceDevice]?.requestedImageFeedSources
            if let rs = requestedSources {
                if rs.contains(Common.currentDevice()) { // Finally we're asking if this device has been requested to provide a feed
                    return true
                }
            }
        }
        return false

        //let count = globalState.devicesState.values.filter { $0.imageDisplayEnabled == true }.count

    }

    
    struct EncodableThermalState: Codable, Equatable {
        let thermalState: ProcessInfo.ThermalState

        static func ==(lhs: EncodableThermalState, rhs: EncodableThermalState) -> Bool {
            return lhs.thermalState == rhs.thermalState
        }
        
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
    
    struct EncodableBatteryState: Codable, Equatable {
        
        var batteryState = UIDevice.current.batteryState
        static func ==(lhs: EncodableBatteryState, rhs: EncodableBatteryState) -> Bool {
            return lhs.batteryState == rhs.batteryState
        }
        
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
                throw DecodingError.dataCorruptedError(forKey: .batteryState, in: container, debugDescription: "Invalid battery state raw value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(batteryState.rawValue, forKey: .batteryState)
        }
    }

    
}

extension ARFrame.WorldMappingStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let value = ARFrame.WorldMappingStatus(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid raw value for ARFrame.WorldMappingStatus")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
