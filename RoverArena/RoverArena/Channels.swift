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
    
    let eid_command: Int8 = 1
    let eid_image: Int8 = 2
    let eid_state: Int8 = 3
    let eid_collaboration: Int8 = 4
    
    enum ContentType: Int8, CaseIterable {
        case command = 1
        case image = 2
        case state = 3
        case collaboration = 4
    }
    
    var consumerIdentity = ""
    
    var consumerControllers:  [SourceDevice: ElementalController] = [:]
    let serverController = ElementalController()
    
    var consumerDevices: [SourceDevice: Device] = [:]
    var serverDevices: [SourceDevice: ServerDevice] = [:]
    
    var consumerElements = [ContentType: Element]()
    var serverElements = [ContentType: Element]()
    
    var deviceConnectedHandler: DeviceConnectedHandler?
    
    var controllerDevices: Set<SourceDevice>?
    
    var imagePollingActive = false
    var imageProcessingEnabled = false
    var currentScreenImage = UIImage() {
        didSet {
            imageAlreadySent = false
        }
    }
    var imageProcessingFPS: Double = 45
    var imageAlreadySent = true // false will break this
    
    init() {
        
        
        // Avoids issues with unwrapping
        /*
         for contentType in ContentType.allCases {
         for sourceDevice in SourceDevice.allCases {
         serverElements[contentType] = [sourceDevice: Element()]
         consumerElements[contentType] = [sourceDevice: Element()]
         }
         }
         */
        
        for contentType in ContentType.allCases {
            handlers[contentType] = [:]
            for sourceDevice in SourceDevice.allCases {
                handlers[contentType]![sourceDevice] = { sourceDevice, imageData in }
            }
        }
    }
    
    // Broadcast the state of the world to all consumer devices
    func broadcastWorldState() {
        let globalStateJSON = try! jsonEncoder.encode(SystemState.shared.globalState)
        for device in consumerDevices.keys {
            sendCommand(type: .worldStatusUpdate, floatValue: 0.0, pointValue: CGPointZero, stringValue: "", boolValue: false, dataValue: globalStateJSON, toDevice: device)
        }
    }
    
    
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
    
    /*
     public func setCommandHandler(_ handler: @escaping CommandHandler, forDevice: SourceDevice) {
     
     commandHandlers[forDevice] = handler
     
     }
     */
    public func setHandler(_ handler: @escaping Handler<Any>, forContentType: ContentType, sourceDevice: SourceDevice) {
        logDebug("Setting handler for content type \(forContentType) for device \(sourceDevice)")
        handlers[forContentType]?[sourceDevice] = handler
    }
    /*
     private func processDataFromDevice(_ device: SourceDevice, type: ContentType, element: Element) {
     
     guard let h = handlers[device] else { return }
     
     if let data = element.dataValue {
     if let command = try? jsonDecoder.decode(Command.self, from: data) {
     h(device, command)
     }
     }
     }
     */
    
    /* With return value...
     private func executeHandler<T: Decodable>(sourceDevice: SourceDevice, contentType: ContentType, dataType: T.Type, element: Element) -> T? {
     logDebug("Executing handler for content type \(contentType) for device \(sourceDevice)")
     if let contentTypeHandlers = handlers[contentType] {
     if let h = contentTypeHandlers[sourceDevice] {
     if let data = element.dataValue {
     let decodedObject = try! jsonDecoder.decode(dataType.self, from: data)
     h(sourceDevice, decodedObject)
     return decodedObject
     }
     }
     }
     return nil
     }
     */
    
    private func executeHandler<T: Decodable>(sourceDevice: SourceDevice, contentType: ContentType, dataType: T.Type, element: Element) {
        if contentType != .image { logDebug("Executing handler for content type \(contentType) for device \(sourceDevice)") }
        if let handler = handlers[contentType]?[sourceDevice] {
            if let data = element.dataValue {
                if dataType == Data.self {
                    handler(sourceDevice, data)
                } else {
                    let decodedObject = try! jsonDecoder.decode(dataType.self, from: data)
                    handler(sourceDevice, decodedObject)
                }
            }
        }
        
    }
    
    func reportDeviceStatusToHubDevice() {
        if !Common.isHub() {
            do {
                //let encodedDeviceState = try self.jsonEncoder.encode(SystemState.shared.myDeviceState)
                sendContentTypeToSourceDevice(Common.shared.hubDevice(), toServer: true, type: ContentType.state, data: SystemState.shared.myDeviceState)
            } catch {
                logError("Recieved encoding error with DeviceState")
            }
        }
        
    }
    
    public func sendContentTypeToSourceDevice<T>(_ sourceDevice: SourceDevice, toServer: Bool, type: ContentType, data: T) where T : Encodable {
        
        if SystemState.shared.myDeviceState.channelStatus != .disconnected {
            if !toServer {
                if let device = consumerDevices[sourceDevice], let element = serverElements[type] {
                    sendUsingDevice(device, element)
                }
                
            } else {
                if let device = serverDevices[sourceDevice], let element = consumerElements[type] {
                    sendUsingDevice(device, element)
                }
            }
        }
        
        
        func sendUsingDevice(_ device: Device, _ element: Element) {
            
            //print("Consumer elements for type \(type) is \(consumerElements)")
            
            //if let element = serverElements[sourceDevice] {
            do {
                if type != .image {
                    let jsonData = try self.jsonEncoder.encode(data)
                    element.dataValue = jsonData
                } else {
                    element.dataValue = data as! Data
                }
                do {
                    try device.send(element: element)
                } catch {
                    logError("\(type) transmission failed to device: \(sourceDevice.rawValue)")
                }
            }
            catch {
                logError("JSON encoding error on element \(element.displayName)")
            }
            //}
            
        }
        
    }
    //  as! T.Type
    
    func processObjectIncomingFromDevice(sourceDevice: SourceDevice, contentType: ContentType, element: Element) {
        
        if contentType != .image { logDebug("Processing incoming object from device \(sourceDevice) of content type \(contentType)") }
        switch contentType {
            
        case .command:
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: Command.self, element: element)
        case .image:
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: Data.self, element: element)
            processImageFromDevice(sourceDevice, element: element)
        case .state:
            SystemState.shared.processIncomingDeviceState(data: element.dataValue)
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: SystemState.DeviceState.self, element: element)
        case .collaboration:
            executeHandler(sourceDevice: sourceDevice, contentType: contentType, dataType: Data.self, element: element)
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
        }
        
        
    }
    
    /*
     private func processCollaborationFromDevice(_ device: SourceDevice, element: Element) {
     
     guard let h = collaborationHandlers[device] else { return }
     
     if let data = element.dataValue {
     h(device, data)
     }
     
     }
     */
    
    
    func annonceSessionID(_ sessionID: String) {
        SystemState.shared.myDeviceState.sessionIdentifier = sessionID
    }
    
    public func setupConsumerOfServerDevice(_ sourceDevice: SourceDevice) {
        
        let elementalController = ElementalController()
        consumerControllers[sourceDevice] = elementalController
        
        let serviceName = Common.serviceNameFor(sourceDevice: sourceDevice, serviceTypeName: "Channel")
        
        let deviceNamed = Common.sourceDeviceFromHostName().rawValue
        
        print("Setting up \(Common.getHostDevice().rawValue) as consumer of \(sourceDevice.rawValue), service name: \(serviceName), deviceNamed: \(deviceNamed)")
        
        elementalController.setupForBrowsingAs(deviceNamed: Common.sourceDeviceFromHostName().rawValue)
        
        elementalController.browser.events.foundServer.handler { device in
            
            self.serverDevices[sourceDevice] = (device as! ServerDevice)
            
            device.events.deviceDisconnected.handler = { _ in
                if sourceDevice == Common.shared.hubDevice() {
                    SystemState.shared.devicesState[sourceDevice] = SystemState.DeviceState(sourceDevice: sourceDevice)
                    SystemState.shared.devicesState[sourceDevice]?.refreshUI = true
                    SystemState.shared.devicesState[sourceDevice]?.refreshUI = false
                    /*
                    if var deviceState = SystemState.shared.devicesState[sourceDevice] {
                        deviceState.channelStatus = .disconnected
                        SystemState.shared.devicesState[sourceDevice] = deviceState
                    }
                     */
                }
                self.serverDevices[sourceDevice] = nil
                logAlert("\(self.consumerIdentity) disconnected from \(serviceName)")
                sleep(2) // Be careful about browing too soon because we may pick up the ghost of the previous service
                elementalController.browser.browseFor(serviceName: serviceName)

            }
            
            device.events.connected.handler = { [self] (device) in
                
                if sourceDevice == Common.shared.hubDevice() {
                    SystemState.shared.myDeviceState.channelStatus = .consumer
                }
                
                for contentType in ContentType.allCases {
                    let element = device.attachElement(Element(identifier: contentType.rawValue, displayName: "Content Type id #\(contentType)", proto: .tcp, dataType: .Data))
                    
                    
                    element.handler = { element, device in
                        
                        if let contentType = ContentType(rawValue: element.identifier) {
                            self.processObjectIncomingFromDevice(sourceDevice: sourceDevice, contentType: contentType, element: element)
                        } else {
                            fatalError("Could not handle content type")
                        }
                    }
                    
                    self.consumerElements[contentType] = element
                    
                    /*
                     if let elements = self.elementsConsumer[contentType] {
                     let element = device.attachElement(Element(identifier: contentType.rawValue, displayName: "Content Type id #\(contentType)", proto: .tcp, dataType: .Data))
                     /*
                      element.handler = {
                      print("Handler for consumer element goes here")
                      }
                      elements[serviceDevice] = element
                      */
                     }
                     */
                    
                }

                
                /*
                 self.consumerImageElements[serviceDevice]?.handler = { element, device in
                 
                 let device = Common.sourceDeviceFromString(deviceName: device.displayName)
                 self.processImageFromDevice(device, element: element)
                 }
                 */
            }
            
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
            if self.consumerDevices.count == 0 {
                SystemState.shared.myDeviceState.channelStatus = .disconnected
            }
            SystemState.shared.devicesState[sourceDevice] = SystemState.DeviceState(sourceDevice: sourceDevice)
            // SystemState.shared.devicesState[sourceDevice]?.channelStatus = .disconnected
            
            logDebug("Got device disconnect for service: \(serviceName) device: \(sourceDevice)")
            
        }
        
        serverController.service.events.deviceConnected.handler = {  _, device in
            
            if Common.getHostDevice() == Common.shared.hubDevice() {
                SystemState.shared.myDeviceState.channelStatus = .server
            }
            let clientDevice = device as! ClientDevice
            
            sleep(1) // Fudge factor because otherwise the client device seems to be the host device but isn't
            
            var sourceDevice = Common.sourceDeviceFromString(deviceName: clientDevice.displayName)
            
            print("Client device \(clientDevice.displayName) (source: \(sourceDevice.rawValue) connected to \(Common.getHostDevice()) -> other: \(clientDevice))")
            
            self.consumerDevices[sourceDevice] = clientDevice
            
            for contentType in ContentType.allCases {
                
                let element = device.attachElement(Element(identifier: contentType.rawValue, displayName: "Content Type id #\(contentType)", proto: .tcp, dataType: .Data))
                element.handler = { element, device in
                    
                    if let contentType = ContentType(rawValue: element.identifier) {
                        self.processObjectIncomingFromDevice(sourceDevice: sourceDevice, contentType: contentType, element: element)
                    } else {
                        fatalError("Could not handle content type")
                    }
                }
                self.serverElements[contentType] = element
            }
            
            self.deviceConnected(device: clientDevice)
            
        }
        
        do {
            try serverController.service.publish(onPort: 0)
            
        } catch {
            logDebug("\(serviceName) could not publish: \(error)")
        }
        
    }
    
    public func broadcastHubDeviceStateToAllDevices() {
        
        for sourceDevice in consumerDevices.keys {
            sendContentTypeToSourceDevice(sourceDevice, toServer: false, type: .state, data: SystemState.shared.myDeviceState)
        }
    }
    
    public func sendContentTypeDataToAllClientDevices(_ type: ContentType, data: Data) {
        
        for sourceDevice in consumerDevices.keys {
            sendContentTypeToSourceDevice(sourceDevice, toServer: false, type: type, data: data)
        }
        
    }
    
    
    
    /*
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
     if let deviceState = SystemState.shared.worldState.devicesState[device] {
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
     */
    
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
    
    /*
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
     */
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
            
            //if let elementsForType = consumerElements[.command] {
            if let element = consumerElements[.command] {
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
            //}
            
        }
    }
    
    
    
}

/*========== Copilot Suggestion 1/1
extension ServerController: NetServiceDelegate {
    
    public func netServiceDidPublish(_ sender: NetService) {
        logDebug("Published service: \(sender.name)")
        logDebug("Service type: \(sender.type)")
        logDebug("Service domain: \(sender.domain)")
        logDebug("Service port: \(sender.port)")
        
        //self.service = sender
        //self.service.delegate = self
        //self.service.resolve(withTimeout: 5.0)
        
    }
    
    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        logDebug("Service did not publish: \(errorDict)")
    }
    
    public func netServiceDidResolveAddress(_ sender: NetService) {
        logDebug("Resolved service: \(sender.name)")
        logDebug("Service type: \(sender.type)")
        logDebug("Service domain: \(sender.domain)")
        logDebug("Service port: \(sender.port)")
        logDebug("Service addresses: \(sender.addresses)")
        
        //self.service = sender
        //self.service.delegate = self
        //self.service.resolve(withTimeout: 5.0)
        
    }
    
    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        logDebug("Service did not resolve: \(errorDict)")
    }
    
    public func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        logDebug("Accepted connection from \(sender.name)")
        
        //self.inputStream = inputStream
        //self.outputStream = outputStream
        
        //self.inputStream?.delegate = self
        //self.outputStream?.delegate = self
        
        //self.inputStream?.schedule(in: RunLoop.current, forMode: .common)
        //self.outputStream?.schedule(in: RunLoop.current, forMode: .common)
        
        //self.inputStream?.open()
        //self.outputStream?.open()
        
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logDebug("Found service: \(service.name)")
        logDebug("Service type: \(service.type)")
        logDebug("Service domain: \(service.domain)")
        logDebug("Service port: \(service.port)")
        
        //self.service = service
        //self.service.delegate = self

*///======== End of Copilot Suggestion
