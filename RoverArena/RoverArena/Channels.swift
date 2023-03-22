//
//  Channels.swift
//  RoverArena
//
//  Created by Rob Reuss on 2/22/23.
//

import Foundation
import ElementalController
import RoverFramework
import ARKit

class Channels {
    
    public static let shared = Channels()
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    
    enum VideoSource: Encodable, Decodable {
        case localAR
        case onboardSource
    }
    
    var worldState: Channels.WorldState = Channels.WorldState() {
        didSet {
            
            // Update UI here
            
        }
    }
    var localDeviceState: Channels.DeviceState = Channels.DeviceState(imageDisplayEnabled: false)

    public struct WorldState: Encodable, Decodable {

        var devicesState: [SourceDevice: DeviceState] = [.iPhone12Pro: DeviceState(), .iPadPro12: DeviceState(), .iPhone14ProMax: DeviceState(), .iPhoneXSMax: DeviceState()]

        
    }

    // Broadcast the state of the world to all consumer devices
    func broadcastWorldState() {
        let worldStateJSON = try! jsonEncoder.encode(worldState)
        for device in consumerDevices.keys {
            sendCommand(type: .worldStatusUpdate, floatValue: 0.0, pointValue: CGPointZero, stringValue: "", boolValue: false, dataValue: worldStateJSON, toDevice: device)
        }
    }
    
    public var imageFeedRequired: Bool {
        let count = worldState.devicesState.values.filter { $0.imageDisplayEnabled == true }.count
        if count > 0 {
            return true
        } else {
            return false
        }
    }
    
    public enum DeviceP2PConnectedStatus: String, Encodable, Decodable {
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
    
    struct DeviceState: Encodable, Decodable {
        //let statusMappingToString: [ARFrame.WorldMappingStatus: String] = [.notAvailable: "Not Available", .limited: "Limited", .extending: "Extending", .mapped: "Mapped"]
        var sourceDevice: SourceDevice = .none
        var sessionIdentifier: String = ""
        var videoSourceDisplaying: VideoSource  = .localAR // UI tracking value
        var deviceConnectedStatus: DeviceP2PConnectedStatus = .disconnected
        var imageDisplayEnabled: Bool = false
        var worldMappingStatus: WorldMappingStatus = .notAvailable
    }

    public enum CommandType: Int16, Codable {
        
        case scanWorld
        case buildArena
        case roverReturnHome
        case roverRotateDegrees
        case beginTransitToPoint
        case cancelTransitToPoint
        case imagefeedRequest
        case broadcastSessionID
        case worldStatusUpdate
        case deviceStatusUpdate
    }
    
    struct Command: Codable {
        
        var type = CommandType.roverReturnHome
        var floatValue: Float = 0.0
        var pointValue: CGPoint = CGPoint(x: 0.0, y: 0.0)
        var stringValue = ""
        var boolValue = false
        var dataValue = Data()
        //var simd4String = ""

        init(type: CommandType, floatValue: Float, pointValue: CGPoint, stringValue: String = "", boolValue: Bool, dataValue: Data) {
            self.type = type
            self.floatValue = floatValue
            self.pointValue = pointValue
            self.stringValue = stringValue
            self.boolValue = boolValue
            self.dataValue = dataValue
        }
        
    }

    public typealias DeviceConnectedHandler = (SourceDevice) -> Void
    public typealias CommandHandler = (SourceDevice, Command) -> Void
    public typealias ImageHandler = (SourceDevice, Data) -> Void
    public typealias CollaborationHandler = (SourceDevice, Data) -> Void

    let eid_command: Int8 = 1
    let eid_image: Int8 = 2
    let eid_collaboration: Int8 = 3
    
    var consumerIdentity = ""
    
    var consumerControllers:  [SourceDevice: ElementalController] = [:]
    let serverController = ElementalController()
    
    var consumerDevices: [SourceDevice: Device] = [:]
    var serverDevices: [SourceDevice: ServerDevice] = [:]
    
    var consumerCommandElements: [SourceDevice: Element] = [:]
    var serverCommandElements: [SourceDevice: Element] = [:]
    
    var consumerImageElements: [SourceDevice: Element] = [:]
    var serverImageElements: [SourceDevice: Element] = [:]
    
    var consumerCollaborationElements: [SourceDevice: Element] = [:]
    var serverCollaborationElements: [SourceDevice: Element] = [:]
    
    var deviceConnectedHandler: DeviceConnectedHandler?
    var commandHandlers: [SourceDevice: CommandHandler] = [:]
    var imageHandlers: [SourceDevice: ImageHandler] = [:]
    var collaborationHandlers: [SourceDevice: CollaborationHandler] = [:]
    
    var controllerDevices: Set<SourceDevice>?
    var imagePollingActive = false
    var imageProcessingEnabled = false
    var currentScreenImage = UIImage() {
        didSet {
            imageAlreadySent = false
        }
    }
    var imageProcessingFPS: Double = 30
    var imageAlreadySent = true // false will break this
    
    func deviceConnected(device: Device) {
        
        guard let h = deviceConnectedHandler else { return }
        let sourceDevice = Common.sourceDeviceFromString(deviceName: device.displayName)
        h(sourceDevice)
        
    }
    
    public func becomeConsumerOfAllDevices() {
        
        for device in Common.deviceSet {
            
            if device != Common.getHostDevice() {
                setupConsumerOfServerDevice(device)
            }
            
        }
        
    }
    
    public func setCommandHandler(_ handler: @escaping CommandHandler, forDevice: SourceDevice) {
        
        commandHandlers[forDevice] = handler
        
    }
    
    public func setImageHandler(_ handler: @escaping ImageHandler, forDevice: SourceDevice) {
        
        imageHandlers[forDevice] = handler

    }
    
    public func setCollaborationHandler(_ handler: @escaping CollaborationHandler, forDevice: SourceDevice) {
        
        collaborationHandlers[forDevice] = handler

    }
    
    private func processCommandFromDevice(_ device: SourceDevice, element: Element) {
        
        guard let h = commandHandlers[device] else { return }
        
        if let data = element.dataValue {
            if let command = try? jsonDecoder.decode(Command.self, from: data) {
                h(device, command)
            }
        }
        
    }
    
    var startDate = Date()
    var imageCount = 0.0
    var timeInterval = 4.0
    private func processImageFromDevice(_ device: SourceDevice, element: Element) {
        
        guard let h = imageHandlers[device] else { return }
        
        imageCount += 1
        let elapsed = abs(startDate.timeIntervalSinceNow)
        if elapsed >= 4.0 {
            let fps = imageCount / timeInterval
            print("Received FPS: \(fps) - images: \(imageCount), elapsed: \(elapsed)")
            startDate = Date()
            imageCount = 0
        }
        
        if let data = element.dataValue {
            h(device, data)
        }
        
    }

    private func processCollaborationFromDevice(_ device: SourceDevice, element: Element) {
        
        guard let h = collaborationHandlers[device] else { return }
        
        if let data = element.dataValue {
            h(device, data)
        }
        
    }

    func reportDeviceStatusToOnboardDevice() {
        let deviceEncoded = try! jsonEncoder.encode(localDeviceState)
        sendCommand(type: .deviceStatusUpdate, floatValue: 0.0, pointValue: CGPointZero, stringValue: "", boolValue: false, dataValue: deviceEncoded, toDevice: Common.shared.unwrappedDeviceType(.onboard))
    }
    
    func annonceSessionID(_ sessionID: String) {
        localDeviceState.sessionIdentifier = sessionID
        print("Accouncing session ID broadcast from \(Common.getHostDevice())")
        reportDeviceStatusToOnboardDevice()
        //sendCommand(type: .broadcastSessionID, floatValue: 0.0, pointValue: CGPointZero, stringValue: sessionID, boolValue: false, dataValue: Data(), toDevice: Common.shared.unwrappedDeviceType(.onboard))
    }
    
    public func setupConsumerOfServerDevice(_ serviceDevice: SourceDevice) {

        let elementalController = ElementalController()
        consumerControllers[serviceDevice] = elementalController
        
        let serviceName = Common.serviceNameFor(sourceDevice: serviceDevice, serviceTypeName: "Channel")
        
        let deviceNamed = Common.sourceDeviceFromHostName().rawValue

        print("Setting up \(Common.getHostDevice().rawValue) as consumer of \(serviceDevice.rawValue), service name: \(serviceName), deviceNamed: \(deviceNamed)")
        
        elementalController.setupForBrowsingAs(deviceNamed: Common.sourceDeviceFromHostName().rawValue)
        
        elementalController.browser.events.foundServer.handler { device in
            
            self.serverDevices[serviceDevice] = device
            
            device.events.deviceDisconnected.handler = { _ in
                self.serverDevices[serviceDevice] = nil
                logAlert("\(self.consumerIdentity) disconnected from \(serviceName)")
                sleep(2) // Be careful about browing too soon because we may pick up the ghost of the previous service
                elementalController.browser.browseFor(serviceName: serviceName)
            }
            
            self.consumerCommandElements[serviceDevice] = device.attachElement(Element(identifier: self.eid_command, displayName: "Command", proto: .tcp, dataType: .Data))
            self.consumerImageElements[serviceDevice] = device.attachElement(Element(identifier: self.eid_image, displayName: "Image", proto: .tcp, dataType: .Data))
            self.consumerCollaborationElements[serviceDevice] = device.attachElement(Element(identifier: self.eid_collaboration, displayName: "Collaboration", proto: .tcp, dataType: .Data))
            
            var gameControllerElements = [
                ]

            self.consumerCollaborationElements[serviceDevice]?.handler = { element, device in
                
                let device = Common.sourceDeviceFromString(deviceName: device.displayName)
                self.processCollaborationFromDevice(device, element: element)
                
            }
            
            self.consumerImageElements[serviceDevice]?.handler = { element, device in
                
                let device = Common.sourceDeviceFromString(deviceName: device.displayName)
                self.processImageFromDevice(device, element: element)
                
            }
            
            /*
            device.events.connected.handler = { [self] device in
                
                self.serverDevices[serviceDevice] = device as? ServerDevice
                
                logAlert("\(Common.getHostDevice()) client connected to server \(device.displayName) on service \(serviceName)")
                
            }
            */
            device.connect()
            
        }
        
        elementalController.browser.browseFor(serviceName: serviceName)
        
    }


    public func setupAsServer() {
        

        let thisDevice = Common.getHostDevice()
        
        let serviceName = Common.serviceNameFor(sourceDevice: thisDevice, serviceTypeName: "Channel")
        
        print("Setting up \(thisDevice) to run service \(serviceName)")
        
        serverController.setupForService(serviceName: serviceName, displayName: thisDevice.rawValue)
        
        serverController.service.events.deviceDisconnected.handler =  { _, device in
            
            let sourceDevice = Common.sourceDeviceFromString(deviceName: device.displayName)
            self.consumerDevices[sourceDevice] = nil
            
            logDebug("Got device disconnect for service: \(serviceName) device: \(sourceDevice)")
            
        }
        
        serverController.service.events.deviceConnected.handler = {  _, device in
            
            let clientDevice = device as! ClientDevice
            
            sleep(1) // Fudge factor because otherwise the client device seems to be the host device but isn't
            
            var sourceDevice = Common.sourceDeviceFromString(deviceName: clientDevice.displayName)
            
            print("Client device \(clientDevice.displayName) (source: \(sourceDevice.rawValue) connected to \(Common.getHostDevice()) -> other: \(clientDevice))")
            
            self.consumerDevices[sourceDevice] = clientDevice
            
            self.serverCommandElements[sourceDevice] = clientDevice.attachElement(Element(identifier: self.eid_command, displayName: "Command", proto: .tcp, dataType: .Data))
            self.serverImageElements[sourceDevice] = clientDevice.attachElement(Element(identifier: self.eid_image, displayName: "Image", proto: .tcp, dataType: .Data))
            self.serverCollaborationElements[sourceDevice] = clientDevice.attachElement(Element(identifier: self.eid_collaboration, displayName: "Collaboration", proto: .tcp, dataType: .Data))
      
            self.serverCommandElements[sourceDevice]?.handler = { element, device in
                
                let device = Common.sourceDeviceFromString(deviceName: device.displayName)
                self.processCommandFromDevice(device, element: element)
                
            }
            
            self.deviceConnected(device: device)
            
        }
        
        do {
            try serverController.service.publish(onPort: 0)

        } catch {
            logDebug("\(serviceName) could not publish: \(error)")
        }
        
    }
    
    public func beginScreenshotPolling() {
        
        imageProcessingEnabled = true
        
        if imagePollingActive { return }
        imagePollingActive = true
        let backgroundQueue = DispatchQueue(label: "com.example.app.backgroundQueue", qos: .background)
        
        //let queue = DispatchQueue(label: "com.example.app.imageProcessing", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
        // let semaphore = DispatchSemaphore(value: 3)
        
        
        print("Started image polling")
        
        //semaphore.wait()
        
        var startDate = Date()
        var imageCount: Double = 0.0
        var samplingImageCount: Double = 180.0
        
        backgroundQueue.async { [self] in
            

            while self.imageProcessingEnabled {
                
                autoreleasepool {
                    //if let unwrappedImage = image {
                    //defer { semaphore.signal() }
                    var cachedImageData: Data?
                    if !self.imageAlreadySent {
                        for device in self.controllerDevices! {
                            if device != Common.getHostDevice() {
                                if let deviceState = self.worldState.devicesState[device] {
                                    if deviceState.imageDisplayEnabled {
                                        if let i = cachedImageData {
                                            self.sendImageData(i, toDevice: device)
                                            //print("Sending cached image")
                                        } else {
                                            if let imageData = self.currentScreenImage.jpegData(compressionQuality: 0.3) {
                                                cachedImageData = imageData
                                                self.sendImageData(imageData, toDevice: device)
                                                //print("Sending new image")
                                            }
                                        }
                                    }
                                    
                                }
                            }
                            
                        }
                        //print("Clearing cache")
                        cachedImageData = Data()
                        
                    }
                    imageAlreadySent = true
                    usleep(10000)
                    
                }
            }
            self.imagePollingActive = false
        }
    }
        
        /*
         /*
         //if let imageData = self.currentScreenImage.pngData() {
             
             //print("Image data size: \(imageData.count)")
             //self.channels.sendImageDataToAllClientDevices(imageData)

                             imageCount += 1
                             if imageCount > samplingImageCount {
                                 let elapsedSeconds = abs(startDate.timeIntervalSinceNow)
                                 // 3 seconds, 60 fps, imagecount = 180
                                 print("FPS: \(imageCount / elapsedSeconds)")
                                 startDate = Date()
                                 imageCount = 0
                             }
                         }
                     }
                 }
             }
          */

         //}
         //usleep(10000)
         //let sleepTime = Float((1 / self.imageProcessingFPS) * 1000000)
         //usleep(useconds_t(sleepTime))
     }
         */
    
    public func sendImageDataToAllClientDevices(_ imageData:Data) {
        
        for sourceDevice in consumerDevices.keys {
            sendImageData(imageData, toDevice: sourceDevice)
        }
        
    }
    
    public func sendImageData(_ imageData: Data, toDevice: SourceDevice) {

        if let device = consumerDevices[toDevice] {
            
            if let element = serverImageElements[toDevice] {
                element.dataValue = imageData
                do {
                    try device.send(element: element)
                    
                } catch {
                    logError("Image transmission failed to device: \(toDevice.rawValue)")
                }
            }
            
        }
    }
    
    public func sendCollaborationData(_ collaborationData: Data) {

       // print("about to send collaboration data")
        for sourceDevice in consumerDevices.keys {

            if sourceDevice != Common.getHostDevice() {

                if let device = consumerDevices[sourceDevice] {
                    
                    if let element = serverCollaborationElements[sourceDevice] {
                        element.dataValue = collaborationData
                        do {
                            //print("Sending collaboration data from \(Common.getHostDevice())to: \(sourceDevice.rawValue), using element \(element.displayName)")
                            try device.send(element: element)
                        } catch {
                            logError("Collaboration transmission failed to device: \(sourceDevice.rawValue)")
                        }
                    }
                    
                }
            }
        }
    }
    
    struct MatrixData: Encodable {
        let matrix: simd_float4x4

        enum CodingKeys: String, CodingKey {
            case matrix
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode([
                matrix[0][0], matrix[0][1], matrix[0][2], matrix[0][3],
                matrix[1][0], matrix[1][1], matrix[1][2], matrix[1][3],
                matrix[2][0], matrix[2][1], matrix[2][2], matrix[2][3],
                matrix[3][0], matrix[3][1], matrix[3][2], matrix[3][3]
            ], forKey: .matrix)
        }
    }
      
    public func sendCommand(type: CommandType, floatValue: Float, pointValue: CGPoint, stringValue: String, boolValue: Bool, dataValue: Data, toDevice: SourceDevice) {
        
        if let device = serverDevices[toDevice] {
            
            if let element = consumerCommandElements[toDevice] {
                let command = Command(type: type, floatValue: floatValue, pointValue: pointValue, stringValue: stringValue, boolValue: boolValue, dataValue: dataValue)
                 
                /*
                let matrixData = MatrixData(matrix: transform)
                let jsonData = try! JSONEncoder().encode(matrixData)
                let simd4String = String(data: jsonData, encoding: .utf8)!

                 */

                //let command = Command(type: type, floatValue: floatValue, pointValue: pointValue, simd4String: simd4String
                let jsonCommand = try! jsonEncoder.encode(command)
                element.dataValue = jsonCommand
                 
                
                do {
                    try device.send(element: element)
                    
                } catch {
                    logError("Command failed: \(type), float: \(floatValue), device: \(toDevice.rawValue)")
                }
                 
            }
            
        }
    }
    

    
}

