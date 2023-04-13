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
    
    
    public enum CommandType: Int16, Codable {
        
        case scanWorld
        case buildArena
        case roverReturnHome
        case roverRotateDegrees
        case beginTransitToPoint
        case cancelTransitToPoint
        case broadcastSessionID
        case worldStatusUpdate
        
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
    //public typealias CommandHandler = (SourceDevice, Command) -> Void
    
    public typealias Handler<T> = (SourceDevice, T) -> Void
    // public typealias Handler = () -> Void
    var handlers: [ContentType: [SourceDevice: Handler<Any>]] = [:]

    enum ContentType: Int8, CaseIterable {
        case command = 1
        case image = 2
        case state = 3
        case cameraTransform = 4
        case collaboration = 5
    }
    
    var consumerIdentity = ""
    
    var consumerControllers:  [SourceDevice: ElementalController] = [:]
    let serverController = ElementalController()
    
    struct ServerDeviceContainer {
        var device: ServerDevice
    }
    
    struct ClientDeviceContainer {
        var device: ClientDevice
    }
    
    var consumerDevices: [String: ClientDeviceContainer] = [:]
    var serverDevices: [String: ServerDeviceContainer] = [:]
    
    struct ElementContainer {
        var element: Element
    }
    
    var consumerElements = [Int8: ElementContainer]()
    var serverElements = [Int8: ElementContainer]()
    
    var deviceConnectedHandler: DeviceConnectedHandler?
    
    var controllerDevices: Set<SourceDevice>?
    
    var imagePollingActive = false
    var imageProcessingEnabled = false
    var currentScreenImage = UIImage() {
        didSet {
            imageAlreadySent = false
        }
    }
    var imageProcessingFPS: Double = 60
    var imageAlreadySent = true // false will break this
    
    init() {

        for contentType in ContentType.allCases {
            handlers[contentType] = [:]
            for sourceDevice in SourceDevice.allCases {
                handlers[contentType]![sourceDevice] = { sourceDevice, imageData in }
            }
        }
    }

    
    func deviceConnected(device: Device) {
        
        guard let h = deviceConnectedHandler else { return }
        let sourceDevice = Common.sourceDeviceFromString(deviceName: device.displayName)
        h(sourceDevice)
        
    }
    
    public func becomeConsumerOfAllDevices() {
        
        for device in Common.deviceSet {
            
            if !device.isCurrentDevice() {
                setupConsumerOfServerDevice(device)
            }
            
        }
        
    }

    public func setHandler(_ handler: @escaping Handler<Any>, forContentType: ContentType, sourceDevice: SourceDevice) {
        logDebug("Setting handler for content type \(forContentType) for device \(sourceDevice)")
        handlers[forContentType]?[sourceDevice] = handler
    }

    
    private func executeHandler<T: Decodable>(sourceDevice: SourceDevice, contentType: ContentType, dataType: T.Type, element: Element) {
        if contentType != .image { logVerbose("Executing handler for content type \(contentType) for device \(sourceDevice)") }
        if let handler = handlers[contentType]?[sourceDevice] {
            if let data = element.dataValue {
                if dataType == Data.self {
                    handler(sourceDevice, data)
                } else {
                    let decodedObject = try! jsonDecoder.decode(dataType.self, from: data)
                    handler(sourceDevice, decodedObject)
                }
            }
        } else {
            print("Handler does not exist")
        }
        
    }
    
    func reportDeviceStatusToHubDevice() {
        if !Common.isHub() {
            do {
                sendContentTypeToSourceDevice(Common.shared.hubDevice(), toServer: true, type: ContentType.state, data: State.shared.currentDeviceState)
            } catch {
                logError("Recieved encoding error with DeviceState")
            }
        }
        
    }
    

    func sendUsingDevice(_ device: Device, _ element: Element) {
        if device.isConnected {
            do {
                try device.send(element: element)
            } catch {
                logError("Transmission failed to device: \(device.displayName)")
            }
        } else {
            print("Attempt to send with no connection")
        }
    }
    
    public func sendCameraTransformToHub(_ sourceDevice: SourceDevice, cameraTransform: simd_float4x4) {

        if let deviceContainer = serverDevices[sourceDevice.rawValue], let elementContainer = consumerElements[ContentType.cameraTransform.rawValue] {

            let tuple = matrixToTuple(matrix: cameraTransform)
            //let matrix = MatrixData(matrix: cameraTransform)
            //let jsonData = try! JSONEncoder().encode(matrix)
            elementContainer.element.tuple4x4Value = tuple
            sendUsingDevice(deviceContainer.device as! ServerDevice, elementContainer.element)
            
        } else {
            //logError("Unable to send \(consumerElements[ContentType.cameraTransform.rawValue] ) using EC device \(serverDevices[sourceDevice.rawValue]) as source device: \(sourceDevice)")
        }
        
    }
    
    public func sendContentTypeToSourceDevice<T>(_ sourceDevice: SourceDevice, toServer: Bool, type: ContentType, data: T) where T : Encodable {
        
        //print("Current device channel status: \(State.shared.currentDeviceState.channelStatus)")
        
        var processedData = Data()
        do {
            
            if type != .image {
                let jsonData = try self.jsonEncoder.encode(data)
                processedData = jsonData
            } else {
                processedData = data as! Data
            }
        }
        catch {
            fatalError("Encoding of data failed")
        }
        
        if !toServer {
            if let deviceContainer = consumerDevices[sourceDevice.rawValue], let elementContainer = serverElements[type.rawValue] {
                let element = elementContainer.element
                element.dataValue = processedData
                sendUsingDevice(deviceContainer.device as! ClientDevice, element)
                logVerbose("Send server type \(type) element \(serverElements[type.rawValue] ) using EC device \(deviceContainer.device) to source device: \(sourceDevice)")

            } else {
                //logError("Unable to send server element \(serverElements[type.rawValue] ) using EC device \(consumerDevices[sourceDevice]) to source device: \(sourceDevice)")
            }
            
        } else {
            if let deviceContainer = serverDevices[sourceDevice.rawValue], let elementContainer = consumerElements[type.rawValue] {
                let element = elementContainer.element
                element.dataValue = processedData
                sendUsingDevice(deviceContainer.device as! ServerDevice, element)
            } else {
                //logError("Unable to send \(consumerElements[type.rawValue] ) using EC device \(serverDevices[sourceDevice.rawValue]) as source device: \(sourceDevice)")
            }
        }

        
    }

    func processObjectIncomingFromDevice(sourceDevice: SourceDevice, contentType: ContentType, element: Element) {
        
        if contentType != .image { logVerbose("Processing incoming object from device \(sourceDevice) of content type \(contentType)") }
        switch contentType {
            
        case .command:
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: Command.self, element: element)
        case .image:
            //executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: Data.self, element: element)
            processImageFromDevice(sourceDevice, element: element)
        case .state:
            State.shared.processIncomingDeviceState(data: element.dataValue)
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: State.DeviceState.self, element: element)
        case .collaboration:
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: Data.self, element: element)
        case .cameraTransform:
            if let tuple = element.tuple4x4Value {
                State.shared.devicesCameraTransforms[sourceDevice] = tupleToSimdFloat4x4(tuple)
                //print("\(sourceDevice) camera transform: \(State.shared.devicesCameraTransforms[sourceDevice])")
            }
        }
        
    }
    
    var startDate = Date()
    var imageCount = 0.0
    var timeInterval = 4.0
    
    private func processImageFromDevice(_ sourceDevice: SourceDevice, element: Element) {
        
        if let handler = handlers[.image]?[sourceDevice] {
            
            imageCount += 1
            let elapsed = abs(startDate.timeIntervalSinceNow)
            if elapsed >= 4.0 {
                let fps = imageCount / timeInterval
                print("Received FPS: \(fps) - images: \(imageCount), elapsed: \(elapsed)")
                startDate = Date()
                imageCount = 0
            }
            
            if let data = element.dataValue {
                handler(sourceDevice, data)
            }
        } else {
            print("Handler does not exist")
        }
        
        
    }

    func annonceSessionID(_ sessionID: String) {
        State.shared.currentDeviceState.sessionIdentifier = sessionID
    }
    
    
    func createElement(contentType: ContentType, device: Device, sourceDevice: SourceDevice) -> Element {
     
        var elementDataType = ElementDataType.Data
        if contentType == .cameraTransform {
            elementDataType = ElementDataType.Tuple4x4Float
        } else {
            elementDataType = ElementDataType.Data
        }
        
        let element = device.attachElement(Element(identifier: contentType.rawValue, displayName: "Content Type id #\(contentType) - eid: \(contentType.rawValue)", proto: .tcp, dataType: elementDataType))
        element.handler = { element, device in
            
            if let contentType = ContentType(rawValue: element.identifier) {
                self.processObjectIncomingFromDevice(sourceDevice: sourceDevice, contentType: contentType, element: element)
            } else {
                fatalError("Could not handle content type")
            }
        }
        
        return element
    }
    
    public func setupConsumerOfServerDevice(_ sourceDevice: SourceDevice) {
        
        let elementalController = ElementalController()
        consumerControllers[sourceDevice] = elementalController
        
        let serviceName = Common.serviceNameFor(sourceDevice: sourceDevice, serviceTypeName: "Channel")
        
        let deviceNamed = Common.sourceDeviceFromHostName().rawValue
        
        print("Setting up \(Common.currentDevice().rawValue) as consumer of \(sourceDevice.rawValue), service name: \(serviceName), deviceNamed: \(deviceNamed)")
        
        elementalController.setupForBrowsingAs(deviceNamed: Common.currentDevice().rawValue)
        
        print("Client device name: \(Common.currentDevice().rawValue)")
        
        elementalController.browser.events.foundServer.handler { device in
            
            self.serverDevices[sourceDevice.rawValue] = ServerDeviceContainer(device: device as! ServerDevice)
            
            device.events.deviceDisconnected.handler = { _ in
                if sourceDevice == Common.shared.hubDevice() {
                    
                    /*
                    State.shared.devicesState[sourceDevice] = State.DeviceState(sourceDevice: sourceDevice)
                    State.shared.devicesState[sourceDevice]?.refreshUI = true
                    State.shared.devicesState[sourceDevice]?.refreshUI = false
                     */
                    /*
                    if var deviceState = SystemState.shared.devicesState[sourceDevice] {
                        deviceState.channelStatus = .disconnected
                        SystemState.shared.devicesState[sourceDevice] = deviceState
                    }
                     */
                }
                self.serverDevices[sourceDevice.rawValue] = nil
                logAlert("\(self.consumerIdentity) disconnected from \(serviceName)")
                sleep(2) // Be careful about browing too soon because we may pick up the ghost of the previous service
                elementalController.browser.browseFor(serviceName: serviceName)

            }
            
            device.events.connected.handler = { [self] (device) in

                for contentType in ContentType.allCases {
                    
                    let element = self.createElement(contentType: contentType, device: device, sourceDevice: sourceDevice)

                    consumerElements[contentType.rawValue] = ElementContainer(element: element)

                    print("Consumer elements: \(self.consumerElements)")


                    // We need to handle the onboard device here
                    if sourceDevice == Common.shared.hubDevice() {
                        State.shared.currentDeviceState.channelStatus = .controller
                    }
                    
                }
                
                State.shared.currentDeviceState.refreshUI = true
                //reportDeviceStatusToHubDevice()
            }
            
            device.connect()
        }
        
        elementalController.browser.browseFor(serviceName: serviceName)
        
        
    }
    
    public func setupAsServer() {
        
        
        let thisDevice = Common.currentDevice()
        
        let serviceName = Common.serviceNameFor(sourceDevice: thisDevice, serviceTypeName: "Channel")
        
        print("Setting up \(thisDevice) to run service \(serviceName)")
        
        serverController.setupForService(serviceName: serviceName, displayName: "\(Common.currentDevice().rawValue)")
        
        serverController.service.events.deviceDisconnected.handler =  { _, device in
            
            let sourceDevice = Common.sourceDeviceFromString(deviceName: device.displayName)
            self.consumerDevices[sourceDevice.rawValue] = nil
            if self.consumerDevices.count == 0 {
                State.shared.currentDeviceState.channelStatus = .disconnected
            }
            State.shared.devicesState[sourceDevice] = State.DeviceState(sourceDevice: sourceDevice)
            // SystemState.shared.devicesState[sourceDevice]?.channelStatus = .disconnected
            
            logDebug("Got device disconnect for service: \(serviceName) device: \(sourceDevice)")
            
        }
        
        serverController.service.events.deviceConnected.handler = {  _, device in
            
            if Common.currentDevice() == Common.shared.hubDevice() {
                State.shared.currentDeviceState.channelStatus = .hub
            }
            let clientDevice = device as! ClientDevice
            
            sleep(1) // Fudge factor because otherwise the client device seems to be the host device but isn't
            
            var sourceDevice = Common.sourceDeviceFromString(deviceName: clientDevice.displayName)

            print("Client device \(clientDevice.displayName) (source: \(sourceDevice.rawValue) connected to \(Common.currentDevice()) -> other: \(clientDevice))")
            
            self.consumerDevices[sourceDevice.rawValue] = ClientDeviceContainer(device: device as! ClientDevice)

            for contentType in ContentType.allCases {

                let element = self.createElement(contentType: contentType, device: device, sourceDevice: sourceDevice)
                
                self.serverElements[contentType.rawValue] = ElementContainer(element: element)

            }
            
            self.deviceConnected(device: clientDevice)
            
        }
        
        do {
            try serverController.service.publish(onPort: 0)
            
        } catch {
            logDebug("\(serviceName) could not publish: \(error)")
        }
        
    }

    public func sendContentTypeDataToAllClientDevices(_ type: ContentType, data: Data) {
        
        for sourceDevice in consumerDevices.keys {
            sendContentTypeToSourceDevice(Common.sourceDeviceFromString(deviceName: sourceDevice), toServer: false, type: type, data: data)
        }
        
    }
    
    func matrixToTuple(matrix: simd_float4x4) -> (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float) {
        let m = matrix.columns
        return (m.0.x, m.0.y, m.0.z, m.0.w,
                m.1.x, m.1.y, m.1.z, m.1.w,
                m.2.x, m.2.y, m.2.z, m.2.w,
                m.3.x, m.3.y, m.3.z, m.3.w)
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
        
        if let deviceContainer = serverDevices[toDevice.rawValue] {
            
            //if let elementsForType = consumerElements[.command] {
            let commandID = ContentType.command.rawValue
            if let elementContainer = consumerElements[commandID] {
                let element = elementContainer.element
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
                    try deviceContainer.device.send(element: element)
                    
                } catch {
                    logError("Command failed: \(type), float: \(floatValue), device: \(toDevice.rawValue)")
                }
                
            }
            //}
            
        }
    }
    
    func tupleToSimdFloat4x4(_ tuple: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)) -> simd_float4x4 {
        var mutableTuple = tuple
        let data = Data(buffer: UnsafeBufferPointer(start: &mutableTuple.0, count: 16))
        return data.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
    }
        
}
