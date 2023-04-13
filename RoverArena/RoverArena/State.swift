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
        
        /* We used to populate the dictionary up front but now simply add states as they arrive
        for sourceDevice in SourceDevice.allCases  {
            devicesState[sourceDevice] = DeviceState(sourceDevice: sourceDevice)
        }
         */
        addObservers()
        
        
        // Create a custom queue for running the timer on a background thread
        let timerQueue = DispatchQueue(label: "com.simplyformed.timerQueue")

        // Create and schedule the timer on the custom queue
        timerQueue.async {
            let timer = DispatchSource.makeTimerSource(queue: timerQueue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(500), leeway: .milliseconds(100))

            // Define the timer action
            timer.setEventHandler {
                State.shared.currentDeviceState.refreshCount += 1

                //print("Current state: \(State.shared.currentDeviceState)")
                
                if Common.isHub() {
                    //State.shared.currentDeviceState.requestedImageFeedSources = [.iPhone12Pro, .iPhone14ProMax]
                }
                
                State.shared.currentDeviceState.batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
                State.shared.currentDeviceState.thermalState = EncodableThermalState(thermalState: ProcessInfo.processInfo.thermalState)
                
                self.devicesState[Common.currentDevice()] = State.shared.currentDeviceState
                
                if Common.isHub() {
                    
                    /*
                    print("Server elements: \(Channels.shared.serverElements)")
                    print("Consumer elements: \(Channels.shared.consumerElements)")
                    
                    print("Consumer devices: \(Channels.shared.consumerDevices)")
                    print("Server devices: \(Channels.shared.serverDevices)")
                    if let stateElementContainer = Channels.shared.serverElements[Channels.ContentType.state.rawValue] {
                        print("state handler: \(stateElementContainer.element.handler)")
                    } else {
                        print("no state element container")
                    }
    */
                    
                    self.updateDevicesWithHubState()
                } else {
                    /*
                    print("Server elements: \(Channels.shared.serverElements)")
                    print("Consumer elements: \(Channels.shared.consumerElements)")
                    
                    print("Consumer devices: \(Channels.shared.consumerDevices)")
                    print("Server devices: \(Channels.shared.serverDevices)")
                     */
                    Channels.shared.reportDeviceStatusToHubDevice()
                }
            }

            // Start the timer
            timer.resume()

            // To cancel the timer at some point, call `timer.cancel()`
            // Note: Make sure to cancel the timer from the same queue it was created on
        }

        
        /*
        let refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            
            State.shared.currentDeviceState.refreshCount += 1

            //print("Current state: \(State.shared.currentDeviceState)")
            
            if Common.isHub() {
                //State.shared.currentDeviceState.requestedImageFeedSources = [.iPhone12Pro, .iPhone14ProMax]
            }
            
            State.shared.currentDeviceState.batteryState = EncodableBatteryState(batteryState: UIDevice.current.batteryState)
            State.shared.currentDeviceState.thermalState = EncodableThermalState(thermalState: ProcessInfo.processInfo.thermalState)
            
            self.devicesState[Common.currentDevice()] = State.shared.currentDeviceState
            
            if Common.isHub() {
                
                /*
                print("Server elements: \(Channels.shared.serverElements)")
                print("Consumer elements: \(Channels.shared.consumerElements)")
                
                print("Consumer devices: \(Channels.shared.consumerDevices)")
                print("Server devices: \(Channels.shared.serverDevices)")
                if let stateElementContainer = Channels.shared.serverElements[Channels.ContentType.state.rawValue] {
                    print("state handler: \(stateElementContainer.element.handler)")
                } else {
                    print("no state element container")
                }
*/
                
                self.updateDevicesWithHubState()
            } else {
                /*
                print("Server elements: \(Channels.shared.serverElements)")
                print("Consumer elements: \(Channels.shared.consumerElements)")
                
                print("Consumer devices: \(Channels.shared.consumerDevices)")
                print("Server devices: \(Channels.shared.serverDevices)")
                 */
                Channels.shared.reportDeviceStatusToHubDevice()
            }


        }
*/
/*
        cancellable = $devicesState.sink { newValue in
            self.updateDevicesWithHubState()
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
 */
         

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

        enum CodingKeys: String, CodingKey {
            case refreshCount
            case launchDate
            case refreshUI
            case sourceDevice
            case sessionIdentifier
            case deviceP2PConnectedStatus
            case worldMappingStatus
            case arMode
            case arWorldMap
            case thermalState
            case batteryLevel
            case batteryState
            case activeImageFeeds
            case requestedImageFeedSources
            case videoSourceDisplaying
            case fps
            case channelStatus
        }
        
        // Not codable
        var cameraTransform = simd_float4x4()
    
        // Codable
        var refreshCount = 0
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
        var requestedImageFeedSources: [SourceDevice] = [] {
            didSet {
                //print("\(sourceDevice): Changed image feed sourced: \(requestedImageFeedSources)")
            }
        }
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
    var devicesCameraTransforms: [SourceDevice: simd_float4x4] = [:]
    @Published var devicesState: [SourceDevice: DeviceState] = [:]
    @Published var currentDeviceState = DeviceState(sourceDevice: Common.currentDevice()) {
        didSet {


        }

    }
  
    /*
    public func resetCurrentDeviceState() {
        currentDeviceState = DeviceState(sourceDevice: Common.currentDevice())
    }
*/
    public func setupCurrentDevice() {

        if UIDevice.current.isBatteryMonitoringEnabled == false {
            UIDevice.current.isBatteryMonitoringEnabled = true
            usleep(500000)
            currentDeviceState.batteryLevel = UIDevice.current.batteryLevel
            currentDeviceState.batteryState.batteryState = UIDevice.current.batteryState
        }

    }
    
    public func processIncomingDeviceState(data: Data?) {
        
        if let d = data {
            
            // Store the incoming device state
            do {
                let deviceState = try jsonDecoder.decode(DeviceState.self, from: d)
                logVerbose("\(Common.currentDevice()) processing incoming device state from \(deviceState.sourceDevice)")
                devicesState[deviceState.sourceDevice] = deviceState
                // Send it to all child devices
                if Common.isHub() { broadcastStateForDevice(deviceState.sourceDevice)  }
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
        if let deviceState = devicesState[Common.currentDevice()] {
            Channels.shared.sendContentTypeToSourceDevice(Common.shared.hubDevice(), toServer: true, type: Channels.ContentType.state, data: deviceState)
        }
        
    }
    
    public func updateDevicesWithHubState() {
        if Common.isHub() {
            for sourceDevice in Common.shared.allOtherDevices  {
                if !Common.isHub(sourceDevice: sourceDevice) {
                    let c = currentDeviceState
                    Channels.shared.sendContentTypeToSourceDevice(sourceDevice, toServer: false, type: Channels.ContentType.state, data: currentDeviceState)
                }
            }
        }
        
        
    }
    
    // Sub-function used by hub when pushing changed device states
    // out to other devices
    public func sendDeviceStateForDevice(_ sourceDeviceForState: SourceDevice, to device: SourceDevice) {
        logVerbose("\(Common.currentDevice()) sending state for device \(sourceDeviceForState) to device \(device)")
        if let deviceState = devicesState[sourceDeviceForState] {
            Channels.shared.sendContentTypeToSourceDevice(device, toServer: false, type: Channels.ContentType.state, data: deviceState)
        }
    }   
    
    // Hub uses this to send updated a device state to all devices
    public func broadcastStateForDevice(_ sourceDeviceForState: SourceDevice) {

        if !Common.isHub() {
            fatalError("Attempt to broadcast device state by non-hub device")
        }
        logVerbose("\(Common.currentDevice()) broadcasting state for device \(sourceDeviceForState)")
        for destinationSourceDevice in Common.shared.allOtherDevices {
            if sourceDeviceForState != destinationSourceDevice {
                sendDeviceStateForDevice(sourceDeviceForState, to: destinationSourceDevice)
            }
        }
        
    }
     
    /*
    // This can be used by hub when it wants to blast all devices with
    // the current state of all devices
    public func broadcastAllDeviceStatesFromHub() {

        for stateSourceDevice in SourceDevice.allCases {
            for destinationSourceDevice in SourceDevice.allCases {
                if destinationSourceDevice != .none {
                    logVerbose("Hub sending state for device \(stateSourceDevice) to device \(destinationSourceDevice)")
                    sendDeviceStateForDevice(stateSourceDevice, to: destinationSourceDevice)
                }
            }
        }
        
    }
     */

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

        var sourceDevicesRequestingImageFeed = Set<SourceDevice>()
        for sourceDevice in SourceDevice.allCases {
            if sourceDevice != Common.currentDevice() {
                if let deviceState = devicesState[sourceDevice] {
                    if sourceDevice == .iPadPro12 { logVerbose("iPad state: \(deviceState)") }
                    let requestedImageFeeds = deviceState.requestedImageFeedSources
                    if requestedImageFeeds.contains(Common.currentDevice()) {
                        logVerbose("Source device \(sourceDevice) requires image feed from \(Common.currentDevice())")
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
            if let deviceState = devicesState[sourceDevice] {
                let requestedSources = deviceState.requestedImageFeedSources
                if requestedSources.contains(Common.currentDevice()) { // Finally we're asking if this device has been requested to provide a feed
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
