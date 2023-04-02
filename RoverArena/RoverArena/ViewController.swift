//
//  ViewController.swift
//  RoverArena
//
//  Created by Rob Reuss on 2/19/23.
//

import UIKit
import RealityKit
import ARKit
import RoverFramework
import ElementalController
import VideoToolbox
import MultipeerConnectivity
import Combine
import AVFoundation
import CoreGraphics

class ViewController: UIViewController, ARSessionDelegate, UIGestureRecognizerDelegate, WorldScanDelegate, AVCaptureFileOutputRecordingDelegate {
    
    var cancellable: AnyCancellable?

    
    var multipeerSession: MultipeerSession?
    var peerSessionIDs = [MCPeerID: String]()
    
    var sessionIDObservation: NSKeyValueObservation?
    
    @IBOutlet weak var arView: ARView!
    
    @IBOutlet weak var coordinates: UILabel!
    
    @IBOutlet weak var message: UILabel!
    
    @IBOutlet weak var commandButtonsView: UIScrollView!
    
    @IBOutlet weak var deviceStatusView: DeviceStatusView!
    
    @IBOutlet var topView: UIView!
    
    var videoStreamViewOnboard: VideoStreamView!
    var videoStreamViewController: VideoStreamView!
    
    var configuration: ARWorldTrackingConfiguration?
    
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    
    var anchorEntity: AnchorEntity?
    var arenaFloorEntity: ModelEntity?
    var roverEntity: ModelEntity?
    
    var channels = Channels.shared
    var common = Common.shared
    
    // var hostDevice: SourceDevice = .iPhone14ProMax
    
    var connectedSourceDevices = Set<SourceDevice>()
    var connectedSourceDevicesSessionIDs = [String: SourceDevice]() // Enables us to map AR sessionIDs to source devices
    
    var gameController = RoverGameController.shared
    
    var arConfiguration: ARWorldTrackingConfiguration?
    // Used by hub exclusively
    //var allDeviceStates: [SourceDevice: Channels.DeviceState] = [:]
    
    func toggleVideoSourceDisplaying() {
        
        //if UIDevice.current.userInterfaceIdiom == .phone {
            if self.deviceRole != .hub {
                if SystemState.shared.myDeviceState.videoSourceDisplaying == .localAR {
                    
                    arView.isHidden = true
                    videoStreamViewOnboard.isHidden = false
                    SystemState.shared.myDeviceState.videoSourceDisplaying = .imageFeed
                    SystemState.shared.myDeviceState.requestedImageFeedSources = [Common.shared.hubDevice()]
                    arView.session.pause()
                    
                } else if SystemState.shared.myDeviceState.videoSourceDisplaying == .imageFeed {
                    
                    arView.isHidden = false
                    videoStreamViewOnboard.isHidden = true
                    SystemState.shared.myDeviceState.videoSourceDisplaying = .localAR
                    SystemState.shared.myDeviceState.requestedImageFeedSources = []
                    if let config = arConfiguration {
                        arView.session.run(config)
                    }
                }
            }
            Channels.shared.reportDeviceStatusToHubDevice()
        //}
        
    }
    
    
    var controllerDevices: Set<SourceDevice>?
    
    var deviceRole: DeviceRole = .hub
    
    var hubDevice: SourceDevice = .iPhone12Pro
    
    /*
    var tripodDevice: SourceDevice {
        return common.unwrappedDeviceType(.tripod)
    }
     */
    // var peerSessionIDs = [SourceDevice: String]()
    
    /* OLD
     func setupCollaborationHandlerForSourceDevice(_ sourceDevice: SourceDevice) {
     
     let collaborationHandler: Channels.CollaborationHandler = {  [self]  sourceDevice, collaborationData in
     receivedCollaborationData(collaborationData, from: sourceDevice)
     }
     channels.setCollaborationHandler(collaborationHandler, forDevice: sourceDevice)
     }
     */
    
    
    
    
    func setupImageHandlerFromSourceDevice(_ sourceDevice: SourceDevice, _ videoStreamView: VideoStreamView) {
        
        let handler: Channels.Handler<Any> = { sourceDevice, imageData in
            if let id = imageData as? Data {
                if let image = UIImage(data: id) {
                    videoStreamView.image = image
                } else {
                    logError("Recieved nil image")
                }
            }
        }
        print("Seeing image handler for source \(sourceDevice)")
        channels.setHandler(handler, forContentType: .image, sourceDevice: sourceDevice)
        
    }

    /* Back from using EC for collaboration
     func setupCollaborators() {
     
     for sourceDevice in deviceRoles.keys {
     if sourceDevice != Common.getHostDevice() {
     setupCollaborationHandlerForSourceDevice(sourceDevice)
     }
     }
     }
     */
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cancellable = SystemState.shared.$myDeviceState.sink(receiveValue: { newValue in
                            DispatchQueue.main.async {
                                switch ProcessInfo.processInfo.thermalState {
                                case .critical, .serious:
                                    self.pauseARSession()
                                case .fair,.nominal:
                                    self.runARSession()
                                }
                            }
                        })
        /*
        cancellable = SystemState.shared.$myDeviceState.sink { newValue in
            switch ProcessInfo.processInfo.thermalState {
            case .critical, .serious:
                self.pauseARSession()
            case .fair,.nominal:
                self.runARSession()
            }
            // print("Heat state is \(ProcessInfo.processInfo.thermalState)")
        }
        */
        usleep(700000) // Prevent coming up with unknown host
        
        let c = common.deviceRoles.filter { $0.value == .controller }
        controllerDevices = Set(c.keys)
        channels.controllerDevices = controllerDevices
        
        hubDevice = common.unwrappedDeviceType(.hub)
        
        arView.session.delegate = self
        
        videoStreamViewOnboard = VideoStreamView(frame: CGRectMake(0.0, 0.0, view.bounds.size.width, view.bounds.size.height))
        videoStreamViewOnboard.backgroundColor = UIColor.purple
        videoStreamViewOnboard.isHidden = true
        topView.addSubview(videoStreamViewOnboard)

        
        UIApplication.shared.isIdleTimerDisabled = true
        
        WorldScan.shared.setup()
        WorldScan.shared.delegate = self
        
        /*
         // Add tap gesture recognizer
         
         
         let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
         doubleTapGesture.delegate = self
         doubleTapGesture.numberOfTapsRequired = 2
         arView.addGestureRecognizer(doubleTapGesture)
         */
        
        /*
         channels.deviceConnectedHandler = { [self] sourceDevice in
         
         self.channels.annonceSessionID(self.arView.session.identifier.uuidString)
         }
         */
        guard let deviceRole = common.deviceRoles[Common.getHostDevice()] else { fatalError("Unknown device role or device") }
        
        self.deviceRole = deviceRole
        
        let controller = controllerDevices
        
        var commandHandler: Channels.Handler<Any> = {_,_ in }
        
        switch deviceRole {
            
        case .none:
            fatalError("Attempt to configure a device referenced as .none")
            
        case .onboard:
            print("Got onboard")
            
        case .tripod:
            print("Got tripod")
            
        case .controller:
            
            channels.setupConsumerOfServerDevice(hubDevice)
            setupImageHandlerFromSourceDevice(hubDevice, videoStreamViewOnboard)
            
            /*
             let tapGesture = UITapGestureRecognizer(target: self, action: #selector(travelToPoint(_:)))
             tapGesture.delegate = self
             arView.addGestureRecognizer(tapGesture)
             */
            
            // PanTilt.shared.setupPanTiltConsumer()
            RoverMotors.shared.connectRoverMotors()
            RoverMotors.shared.accelerationCurve = 0.3
            
            //channels.setupConsumerOfServerDevice(hubDevice)
            // arView.session.pause()
            
            /*
             imageView.backgroundColor = UIColor.black
             imageView.removeFromSuperview()
             self.view.addSubview(imageView)
             imageView.frame = self.view.bounds
             self.view.bringSubviewToFront(imageView)
             */
            /*
             imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
             NSLayoutConstraint.activate([
             imageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
             imageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
             imageView.topAnchor.constraint(equalTo: self.view.topAnchor),
             imageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
             ])
             */
            
            RoverMotors.shared.setupRoverTelemetryClient()
            RoverMotors.shared.onIncomingTelemetryHandler = { telemetry in
                
                print("Telemetry: ")
                
            }
            
            gameController.setupAsRemoteServer()
            setupLocalGameControllerHandlers()
            gameController.discoverGameController()

            
            
            commandHandler = {  [self]  sourceDevice, co in
                
                if let commandObject = co as? Channels.Command {
                    
                    self.runCommonCommandHandler(sourceDevice: sourceDevice, commandObject: commandObject)
                    
                    switch commandObject.type {
                        
                    case .broadcastSessionID:
                        print("Received session ID: \(commandObject.stringValue) from \(sourceDevice)")
                        connectedSourceDevicesSessionIDs[commandObject.stringValue] = sourceDevice
                        
                        
                    default:
                        print("Unhandled command: \(commandObject)")
                    }
                }
            }
            
            
            channels.setupAsServer()
            
            
            
        case .hub:
            
            let videoStreamViewWidth: CGFloat = 633.0
            let videoStreamViewHeight: CGFloat = 293.0
            
            videoStreamViewOnboard.frame = CGRectMake(0.0, 0.0, videoStreamViewWidth, videoStreamViewHeight)
            videoStreamViewOnboard.isHidden = false
            videoStreamViewOnboard.backgroundColor = UIColor.blue
            videoStreamViewOnboard.translatesAutoresizingMaskIntoConstraints = false // This is necessary to enable auto layout
            NSLayoutConstraint.activate([
                videoStreamViewOnboard.leadingAnchor.constraint(equalTo: topView.leadingAnchor, constant: 20),
                videoStreamViewOnboard.topAnchor.constraint(equalTo: topView.topAnchor, constant: 50),
                videoStreamViewOnboard.widthAnchor.constraint(equalToConstant: videoStreamViewWidth),
                videoStreamViewOnboard.heightAnchor.constraint(equalToConstant: videoStreamViewHeight)
            ])

            videoStreamViewController = VideoStreamView(frame: CGRectMake(0.0, videoStreamViewHeight + 10.0, videoStreamViewWidth, videoStreamViewHeight))
            videoStreamViewController.backgroundColor = UIColor.red
            videoStreamViewController.isHidden = false
            topView.addSubview(videoStreamViewController)
            topView.bringSubviewToFront(videoStreamViewController)
            
            videoStreamViewController.translatesAutoresizingMaskIntoConstraints = false // This is necessary to enable auto layout
            NSLayoutConstraint.activate([
                videoStreamViewController.leadingAnchor.constraint(equalTo: topView.leadingAnchor, constant: 20),
                videoStreamViewController.topAnchor.constraint(equalTo: videoStreamViewOnboard.bottomAnchor, constant: 50),
                videoStreamViewController.widthAnchor.constraint(equalToConstant: videoStreamViewWidth),
                videoStreamViewController.heightAnchor.constraint(equalToConstant: videoStreamViewHeight)
            ])
            channels.setupConsumerOfServerDevice(.iPhone14ProMax)
            setupImageHandlerFromSourceDevice(.iPhone14ProMax, videoStreamViewController)

            channels.setupConsumerOfServerDevice(hubDevice)
            setupImageHandlerFromSourceDevice(hubDevice, videoStreamViewOnboard)
            
            commandHandler = {  [self]  sourceDevice, co in
                
                if let commandObject = co as? Channels.Command {
                    
                    self.runCommonCommandHandler(sourceDevice: sourceDevice, commandObject: commandObject)
                    
                    switch commandObject.type {
                        
                    case .broadcastSessionID:
                        print("Received session ID: \(commandObject.stringValue) from \(sourceDevice)")
                        connectedSourceDevicesSessionIDs[commandObject.stringValue] = sourceDevice
                        
                    default:
                        print("Unhandled command: \(commandObject)")
                    }
                }
            }
            
            
            initDeviceStatusView()
            initCommandButtonsViews()

            SystemState.shared.myDeviceState.requestedImageFeedSources = [hubDevice, .iPhone14ProMax]

            //imageView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
            //imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        // case .hub: -> Used to be just hub/onboard
            
            RoverMotors.shared.connectRoverMotors()
            RoverMotors.shared.accelerationCurve = 0.2
            resetPanTilt()
            
            // channels.beginScreenshotPolling()
            //channels.setupConsumerOfServerDevice(.iPadPro12)
            //gameController.setupAsConsumerFrom(sourceDevice: tripodDevice)
            
            
            commandHandler = {  [self]  sourceDevice, co in
                
                if let commandObject = co as? Channels.Command {
                    
                    self.runCommonCommandHandler(sourceDevice: sourceDevice, commandObject: commandObject)
                    
                    switch commandObject.type {
                        
                    case Channels.CommandType.buildArena:
                        logDebug("Recived command to build arena")
                        
                        self.buildArenaOnScreenPoint(getPointForArena())
                        self.addRoverEntity()
                        
                    case Channels.CommandType.cancelTransitToPoint:
                        logDebug("Recived command to cancel transit")
                        self.continueTravelToPoint = false
                        
                        /*
                    case Channels.CommandType.imagefeedRequest:
                        logDebug("Recived command to enable/disable display feed: \(commandObject.boolValue)")
                        SystemState.shared.worldState.devicesState[sourceDevice]?.imageDisplayEnabled = commandObject.boolValue
                        */
                    case Channels.CommandType.beginTransitToPoint:
                        logDebug("Recived command to begin transit")
                        let destinationPoint = commandObject.pointValue
                        travelToPoint(destinationPoint, atSpeed: commandObject.floatValue)
                        
                    case .broadcastSessionID:
                        print("Received session ID: \(commandObject.stringValue) from \(sourceDevice)")
                        connectedSourceDevicesSessionIDs[commandObject.stringValue] = sourceDevice
                        
                        /*
                    case .deviceStatusUpdate:
                        let deviceState = try! jsonDecoder.decode(Channels.DeviceState.self, from: commandObject.dataValue)
                        channels.worldState.devicesState[sourceDevice] = deviceState
                        channels.broadcastWorldState()
                        */
                    default:
                        print("Unhandled command: \(commandObject)")
                    }
                }
            }
            
            if let controllers = controllerDevices {
                for controllerDevice in controllers {
                    gameController.setupAsConsumerFrom(sourceDevice: controllerDevice)
                }
            }
            
            /*
             imageView.isHidden = true
             arView.frame = self.view.bounds
             */
            
            setupLocalGameControllerHandlers()
            //setupRemoteGameControllerHandlers()
            gameController.discoverGameController()
            
            let cameraPosition = arView.cameraTransform.translation // World coordinators
            print("Camera translation: \(cameraPosition)")
            
            channels.setupAsServer()
        }
        
        for device in Common.deviceSet {
            if device != Common.getHostDevice() {
                channels.setHandler(commandHandler, forContentType: .command, sourceDevice: device)
            }
        }
        
        
        sleep(1)

        
    }
    
    
    func runCommonCommandHandler(sourceDevice: SourceDevice, commandObject: Channels.Command) {
        
        /*
        switch commandObject.type {
            
        case .worldStatusUpdate:
            
            if Common.getHostDevice() != hubDevice {
                channels.globalState  = try! jsonDecoder.decode(System.GlobalState.self, from: commandObject.dataValue)
            }
            
        default:
            print("Ignored cases")
        }
        */
    }
    
    
    let commandButtonHeight = 42.0
    let commandButtonSpacing = 5.0
    let commandViewWidth: CGFloat = 250.0
    let commandButtonMargins: CGFloat = 2
    private var commandButtons: [CommandButton] = []
    //public typealias CommandButtonHandler = (action: UIAction) -> Void
    
    func pauseARSession() {
        if SystemState.shared.myDeviceState.arEnabled {
            SystemState.shared.myDeviceState.arEnabled = false
            arView.session.pause()
            SystemState.shared.operationalBrightness = UIScreen.main.brightness
        }
    }
    
    func runARSession() {
        if SystemState.shared.myDeviceState.arEnabled == false {
            print("Ar2: \(SystemState.shared.myDeviceState.arEnabled)")

            arView.session.delegate = self
            arView.automaticallyConfigureSession = false
            arConfiguration = ARWorldTrackingConfiguration()
            if let config = arConfiguration {
                config.planeDetection = [.horizontal]
                config.environmentTexturing = .automatic
                config.isCollaborationEnabled = true
                arView.session.run(config)
            }
            arView.isHidden = false

            let device = Common.shared.unwrappedDeviceType(.hub)
            if device != Common.getHostDevice() {
                SystemState.shared.operationalBrightness = 0.2
            }
            SystemState.shared.myDeviceState.arEnabled = true
            print("Ar3: \(SystemState.shared.myDeviceState.arEnabled)")
        }
    }
    
    
    func initDeviceStatusView() {
        view.bringSubviewToFront(deviceStatusView)
    }
    
    func initCommandButtonsViews() {
        
        //commandButtons = UIView(frame: CGRectMake(0, 0, view.bounds.height * 0.50, 200))
        
        commandButtonsView.backgroundColor = UIColor.darkGray
        //commandButtonsView.touchesShouldCancel(in: commandButtonsView)
        commandButtonsView.delaysContentTouches = true
        
        let refreshAction = UIAction(title: "Refresh") { (action) in
            print("Refresh the data.")
        }
        
        addCommandButton(action: UIAction(title: "Go home", handler: { (action) in
            print("Received: \(action.title)")
        }))
        
        addCommandButton(action: UIAction(title: "Go back", handler: { (action) in
            print("Received: \(action.title)")
        }))
        
        addCommandButton(action: UIAction(title: "Go right", handler: { (action) in
            print("Received: \(action.title)")
        }))
        
        addCommandButton(action: UIAction(title: "Go left", handler: { (action) in
            print("Received: \(action.title)")
        }))
        
        print("Command button count: \(commandButtons.count)")
        let viewHeight = (commandButtonHeight + commandButtonSpacing) * Double(commandButtons.count) + commandButtonMargins
        commandButtonsView.frame = CGRectMake(0, 300, commandViewWidth, viewHeight)
        print("Command button view height: \(commandButtonsView.bounds.height), based on \(viewHeight)")
        /*
         commandButtons.autoresizingMask = [ .flexibleHeight]
         NSLayoutConstraint.activate([
         commandButtons.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
         //imageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
         commandButtons.topAnchor.constraint(equalTo: self.view.topAnchor),
         //imageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
         ])
         */
        
        /*
         imageView.frame = CGRectMake(200, 0, view.bounds.width - 200, view.bounds.height)
         imageView.isHidden = true
         
         arView.frame = CGRectMake(200, 0, view.bounds.width - 200, view.bounds.height)
         arView.isHidden = true
         */
        
        view.bringSubviewToFront(commandButtonsView)
    }
    
    
    
    @objc func buttonTapped(sender: CommandButton, forEvent event: UIEvent) {
        let commandButton = sender as CommandButton
        commandButton.handler()
    }
    
    func addCommandButton(action: UIAction) {
        
        let frame = CGRectMake(commandButtonMargins, (commandButtonHeight + commandButtonSpacing) * Double(commandButtons.count) + commandButtonSpacing, commandViewWidth - (commandButtonMargins * 2), commandButtonHeight)
        let commandButton = CommandButton(type: .system, primaryAction: action)
        commandButton.frame = frame
        
        /*
         // commandButton.setTitle(action.title, for: .normal)
         commandButton.setTitleColor(.black, for: .normal)
         commandButton.tintColor = UIColor.white
         commandButton.backgroundColor = .clear
         //commandButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
         commandButton.layer.shadowColor = UIColor.black.cgColor
         commandButton.layer.shadowOffset = CGSize(width: 0, height: 2)
         commandButton.layer.shadowOpacity = 0.5
         commandButton.layer.shadowRadius = 4
         commandButton.layer.masksToBounds = false
         commandButton.layer.cornerRadius = 2.0
         */
        commandButtonsView.addSubview(commandButton)
        
        commandButton.translatesAutoresizingMaskIntoConstraints = true
        NSLayoutConstraint.activate([
            commandButton.leadingAnchor.constraint(equalTo: commandButtonsView.leadingAnchor),
            commandButton.trailingAnchor.constraint(equalTo: commandButtonsView.trailingAnchor),
        ])
        
        commandButtons.append(commandButton)
        
    }
    
    static func asdlfkj() {
        while true == true {
            print("True")
            continue
        }
        return
    }
    
    override func viewDidAppear(_ animated: Bool) {
 
        let width = arView.bounds.height
        let height = arView.bounds.width
        
        let reticuleSize = 200.0
        let reticuleViewVertical = UIView(frame: CGRect(x: width * 0.50, y: height * 0.50 - (reticuleSize * 0.50), width: 1.0, height: reticuleSize))
        reticuleViewVertical.backgroundColor = UIColor.white
        arView.addSubview(reticuleViewVertical)
        
        let reticuleViewHoritzontal = UIView(frame: CGRect(x: width * 0.50 - (reticuleSize * 0.50), y: height * 0.50, width: reticuleSize, height: 1.0))
        reticuleViewHoritzontal.backgroundColor = UIColor.white
        arView.addSubview(reticuleViewHoritzontal)
        
        // self.view.bringSubviewToFront(imageView)
        initMultipeerSession()
        
    }
    
    func roverMotorsLeftThumbstickHandler() -> RoverGameController.ControllerInputHandler {
        
        let roverMotorsGameControllerHandler: RoverGameController.ControllerInputHandler = { value in
            RoverMotors.shared.rotate(speed: RoverGameController.shared.currentValueForInputType[.leftThumbstickX]!)
        }
        return roverMotorsGameControllerHandler
        
    }
    
    func roverMotorsRightThumbstickHandler() -> RoverGameController.ControllerInputHandler {
        
        let roverMotorsGameControllerHandler: RoverGameController.ControllerInputHandler = { value in
            
            if let rightThumbstickX = self.gameController.currentValueForInputType[.rightThumbstickX], let rightThumbstickY = self.gameController.currentValueForInputType[.rightThumbstickY] {
                RoverMotors.shared.processGameControllerInput(x: rightThumbstickX, y: rightThumbstickY)
                return
            }
            
            
            if let rightThumbstickX = self.gameController.currentValueForInputType[.rightThumbstickX] {
                //print("Remote right thumbstick X: \(rightThumbstickX), Y: \(value)")
                // RoverM weirdotors.shared.processGameControllerInput(x: rightThumbstickX, y: value)
                if let roverEntity = self.roverEntity {
                    /*
                     roverEntity.transform.translation.x = rightThumbstickX
                     roverEntity.transform.translation.y = Float(value)
                     */
                    let force = simd_make_float3(0.12, 0, 0) // Apply a force in the positive y direction
                    let angularVelocity = simd_make_float3(0.0, 0, 0)
                    
                    //roverEntity.addForce([0, 0, 0.9], relativeTo: roverEntity.parent)
                    //roverEntity.physicsMotion?.linearVelocity = [0, 0, 0.1]
                    //roverEntity.applyLinearImpulse([0, 0, 0.002], relativeTo: roverEntity.parent)
                    
                    //roverEntity.physicsMotion?.linearVelocity = [0.5, 0.5]
                    
                    let pmc = PhysicsMotionComponent(linearVelocity: force, angularVelocity: angularVelocity)
                    
                    //roverEntity.physicsMotion = pmc
                    
                    let forceMultiplier: Float = 7.0
                    let xForce = rightThumbstickX * forceMultiplier
                    let yForce = -(value * forceMultiplier)
                    
                    roverEntity.addForce([xForce, 0, yForce], relativeTo: roverEntity.parent)
                    
                    //roverEntity.applyLinearImpulse([0, 0, 0.002], relativeTo: roverEntity.parent)
                    
                    //roverEntity.addTorque([Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4)], relativeTo: nil)
                    
                    //roverEntity.addForce(force, relativeTo: roverEntity.parent)
                }
                
            }
        }
        return roverMotorsGameControllerHandler
    }
    
    func translationFromScreenPoint(point: CGPoint) -> CGPoint {
        
        let raycastResults = self.arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        guard let firstResult = raycastResults.first else {
            //print("[WARNING] No target detected!")
            return CGPointZero
        }
        if let anchor = firstResult.anchor {
            return CGPointMake(CGFloat(anchor.transform.columns.3.x), CGFloat(anchor.transform.columns.3.z))
        } else {
            return CGPointZero
        }
        
    }
    
    
    func setupLocalGameControllerHandlers() {
        
        gameController.localDeviceControllerHandlers[.rightThumbstickY] = roverMotorsRightThumbstickHandler()
        gameController.localDeviceControllerHandlers[.leftThumbstickY] = roverMotorsLeftThumbstickHandler()
        
        gameController.localDeviceControllerHandlers[.rightShoulder] = { value in
            print("Got right shoulder")
            if value == 1.0 {
                
                let destinationPoint = self.translationFromScreenPoint(point: CGPoint(x: self.arView.bounds.height * 0.50, y: self.arView.bounds.width * 0.50))
                self.channels.sendCommand(type: .beginTransitToPoint, floatValue: 0.4, pointValue: destinationPoint, stringValue: "", boolValue: false, dataValue: Data(), toDevice: self.hubDevice)
            }
            
        }
        
        gameController.localDeviceControllerHandlers[.buttonA] = { value in
            print("Got button a: \(value)")
            
            if value == 1.0 {
                self.toggleVideoSourceDisplaying()
            }
            
        }
        
        gameController.localDeviceControllerHandlers[.buttonX] = { value in
            print("Got button x")
            if value == 1.0 {
                self.channels.sendCommand(type: .buildArena, floatValue: 0.0, pointValue: CGPoint(x: 0.0, y: 0.0), stringValue: "", boolValue: false, dataValue: Data(), toDevice: self.hubDevice)
            }
        }
        
        gameController.localDeviceControllerHandlers[.buttonY] = { value in
            print("Got button y")
            if value == 1.0 {
                self.channels.sendCommand(type: .cancelTransitToPoint, floatValue: 0.0, pointValue: CGPoint(x: 0.0, y: 0.0), stringValue: "", boolValue: false, dataValue: Data(),toDevice: self.hubDevice)
            }
        }
    }
    
    func setupRemoteGameControllerHandlers() {
        
        gameController.remoteDeviceHandlers[.buttonX] = { value in
            print("Got button x")
            if value == 1.0 {
                self.buildArenaOnScreenPoint(self.getPointForArena())
                self.addRoverEntity()
            }
        }
        
        gameController.remoteDeviceHandlers[.buttonY] = { value in
            print("Got button y")
            if value == 1.0 {
                //self.channels.sendCommandType(type: .beginTransitToPoint, floatValue: 0.3, pointValue: CGPoint(x: 0.0, y: 0.1), toDevice: self.hubDevice)
            }
        }
        
        gameController.remoteDeviceHandlers[.buttonB] = { value in
            print("Got button b")
            if value == 1.0 {
                // self.channels.sendCommandType(type: .cancelTransitToPoint, floatValue: 0.3, pointValue: CGPoint(x: 0.0, y: 0.1), toDevice: self.hubDevice)
            }
        }
        
        
        gameController.remoteDeviceHandlers[.rightThumbstickX] = { value in
            
            print("Remote right thumbstick X: \(value)")
            
        }
        
        gameController.remoteDeviceHandlers[.leftTrigger] = { value in
            
            print("Left trigger: \(value)")
            
        }
        
        gameController.remoteDeviceHandlers[.rightThumbstickButton] = { value in
            
            if let roverEntity = self.roverEntity {
                
                print("Got right thumb button")
                
                let forceMultiplier: Float = 7.0
                //let xForce = rightThumbstickX * forceMultiplier
                let yForce = -(value * forceMultiplier)
                
                roverEntity.addTorque([Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4), Float.random(in: 0 ... 0.4)], relativeTo:  roverEntity.parent)
                //roverEntity.addForce([7.0, 0, 0.0], relativeTo: roverEntity.parent)
                
            }
            
        }
        
        gameController.remoteDeviceHandlers[.rightThumbstickY] = roverMotorsRightThumbstickHandler()
        
    }
    

    func getPointForArena() -> CGPoint {
        return CGPoint(x: self.view.bounds.width * 0.50, y: self.view.bounds.height * 0.90)
    }
    
    func worldScanComplete() {
        
        PanTilt.shared.tilt(degrees: 70)
        sleep(2)
        
        let anchorPoint = CGPoint(x: self.view.bounds.width * 0.50, y: self.view.bounds.height * 0.90)
        
        //buildArenaAt(anchorPoint)
        
        resetPanTilt()
        
    }
    
    private func removeAllAnchorsOriginatingFromARSessionWithID(_ identifier: String) {
        guard let frame = arView.session.currentFrame else { return }
        for anchor in frame.anchors {
            guard let anchorSessionID = anchor.sessionIdentifier else { continue }
            if anchorSessionID.uuidString == identifier {
                arView.session.remove(anchor: anchor)
            }
        }
    }
    
    
    func resetPanTilt() {
        PanTilt.shared.tilt(degrees: 90)
        PanTilt.shared.pan(degrees:180)
    }
    
    
    var currentDevicePoint: CGPoint {
        
        get {
            let c = arView.cameraTransform.translation
            //let x = CGFloat(round(100 * c.x) / 100)
            //let y = CGFloat(round(100 * c.z) / 100)
            return CGPointMake(CGFloat(c.x), -CGFloat(c.z))
        }
        
    }
    
    var currentCameraPosition: CGPoint = CGPoint(x: 0, y: 0)
    
    var continueTravelToPoint = false
    
    func testEqualityForPoints(_ point1: CGPoint, _ point2: CGPoint, within: CGFloat) -> Bool {
        
        if (point1.x <= point2.x + within) && (point1.x + within >= point2.x) &&
            (point1.y <= point2.y + within) && (point1.y + within >= point2.y) {
            return true
        } else {
            return false
        }
        
    }
    
    func averagePrecision(currentPoint: CGPoint, destinationPoint: CGPoint) -> Float {
        
        let precisionX = abs(currentPoint.x - destinationPoint.x)
        let precisionY = abs(currentPoint.y - destinationPoint.y)
        
        return Float((precisionX + precisionY) * 0.50)
    }
    
    func travelToPoint( _ desinationPoint: CGPoint, atSpeed: Float) {
        
        var speed = atSpeed
        
        continueTravelToPoint = true
        
        var precision = 0.05
        
        DispatchQueue.global().async {
            
            while !self.testEqualityForPoints(self.currentDevicePoint, desinationPoint, within: precision) && self.continueTravelToPoint == true {
                
                let deltaY = desinationPoint.x - self.currentDevicePoint.x
                let deltaX = desinationPoint.y - self.currentDevicePoint.y
                
                var angleInRadians = atan2(deltaX, deltaY)
                let angleInDegrees = angleInRadians * 180 / .pi
                
                // KIND OF WORKING
                let rotationInRadians = CGFloat(self.arView.cameraTransform.rotation.angle)
                // print("Camera rotation: \(self.arView.cameraTransform.rotation.angle)")
                angleInRadians = angleInRadians - rotationInRadians
                
                //print("From: \(self.currentDevicePoint) to \(desinationPoint)    radiansVec: \(angleInRadians), degreesVec: \(angleInDegrees)   rotationRadians: \(rotationInRadians)    atSpeed: \(speed)")
                print("From: \(self.currentDevicePoint) to \(desinationPoint)    radiansVec: \(angleInRadians), degreesVec: \(angleInDegrees)    atSpeed: \(speed) with Precision: \(precision)")
                
                //print("Current device point: \(self.currentDevicePoint), angleRadians: \(angleInRadians), angleDegrees: \(angleInDegrees)")
                //print("Angle between points is \(angleInDegrees) degrees, speed: \(atSpeed)")
                
                if self.averagePrecision(currentPoint: self.currentDevicePoint, destinationPoint: desinationPoint) < 0.10 { // slow way down if getting close
                    speed = atSpeed * 0.60
                    precision = 0.02
                }
                
                RoverMotors.shared.powerMacunumWheelsAt(speed: speed, angleRadians: Float(angleInRadians))
                
                usleep(100000)
            }
            let precisionX = self.currentDevicePoint.x - desinationPoint.x
            let precisionY = self.currentDevicePoint.y - desinationPoint.y
            self.continueTravelToPoint = false
            RoverMotors.shared.brake()
            usleep(500000)
            print("COMPLETED: from: (\(self.currentDevicePoint) to \(desinationPoint): precision: (\(precisionX), \(precisionY)")
            print()
            print()
        }
        
    }
    
    
    func getCameraRelativeToEntity(entity: Entity) -> SIMD3<Float> {
        
        let cameraTransform = entity.transform
        let cameraPositionRelativeToEntity = cameraTransform
        return entity.convert(transform: cameraTransform, from: nil).translation
        
    }
    
    let roverSidesSize: Float = 0.33
    
    func addRoverEntity() {
        
        //let cameraPosition = arView.cameraTransform.translation // World coordinators
        if let arenaFloorEntity = arenaFloorEntity {
            let cameraOffsetFromBackOfRover: Float = 0.08
            let height: Float = 0.16
            let roverMesh = MeshResource.generateBox(width: roverSidesSize, height: height, depth: roverSidesSize)
            let roverMaterial = SimpleMaterial(color: UIColor.yellow.withAlphaComponent(1.0), isMetallic: true)
            roverEntity = ModelEntity(mesh: roverMesh, materials: [roverMaterial])
            if let roverEntity = roverEntity {
                
                let floorTranslation = arenaFloorEntity.transform.translation
                roverEntity.transform.translation = SIMD3<Float>(x: floorTranslation.x, y: floorTranslation.y + (height * 0.50), z: floorTranslation.z - cameraOffsetFromBackOfRover)
                
                let size: Float = 0.33
                let shape = ShapeResource.generateBox(size: SIMD3<Float>(roverSidesSize, height, roverSidesSize))
                
                anchorEntity?.addChild(roverEntity)
                
                roverEntity.collision = CollisionComponent(shapes: [shape])
                roverEntity.physicsBody = PhysicsBodyComponent(
                    massProperties: .init(shape: shape, mass: 3),
                    material: nil,
                    mode: .dynamic
                )
                
                
                
                /*
                 //roverEntity.collision = CollisionComponent(shapes: [shape], mode: .default, filter: .default)
                 let massProperties = PhysicsMassProperties(shape: shape, mass: 0.005)
                 let physicsMaterial = PhysicsMaterialResource.generate(friction: 0.1, restitution: 0.8)
                 roverEntity.physicsBody = PhysicsBodyComponent(massProperties: massProperties, material: physicsMaterial, mode: .kinematic)
                 roverEntity.physicsMotion = PhysicsMotionComponent()
                 */
                
                //let physicsBody = PhysicsBodyComponent(shapes: [ShapeResource.generateBox(size: SIMD3<Float>(roverSidesSize, height, roverSidesSize))], density: 1.0, mode: .kinematic)
                //let physicsBody = PhysicsBodyComponent(shapes: [ShapeResource.generateBox(size: SIMD3<Float>(roverSidesSize, height, roverSidesSize))], mass:  0.005, mode: .kinematic)
                
                //roverEntity.components.set(physicsBody)
                //roverEntity.collision = CollisionComponent(shapes: [.generateBox(width: size, height: size, depth: size)])
                
                
                
                //SIMD3<Float>(x: cameraTransform.translation.x + 0.50, y: anchorEntity.transform.translation.y, z: cameraTransform.translation.z + 0.50)
                
                let waitForUpdate = arView.scene.subscribe(
                    to: SceneEvents.Update.self,
                    on: roverEntity
                ) { event in
                    
                    print("rover position: \(roverEntity.transform.translation)")
                    
                }
            }
            
        } else {
            print("No arena floor entity")
        }
        
    }
    
    func buildArenaOnScreenPoint(_ point: CGPoint) {
        
        print("Creating anchor point at \(point)")
        
        print("Raycasting to point: \(point)")
        let raycastResults = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        guard let firstResult = raycastResults.first else {
            print("[WARNING] No surface detected!")
            return
        }
        buildArenaOnSIMD(firstResult.worldTransform)
    }
    
    func buildArenaOnSIMD(_ simd: simd_float4x4) {
        let arAnchor = ARAnchor(name: "Arena", transform: simd)
        anchorEntity = AnchorEntity(anchor: arAnchor)
        
        guard let anchorEntity = self.anchorEntity else {
            fatalError("Failed to create anthorEntity")
        }
        
        arView.scene.addAnchor(anchorEntity)
        
        print("Building arena on arAnchor: \(arAnchor) for device: \(Common.getHostDevice())")
        
        let feet: Float = 6.0 // replace with your desired feet value - 3.8 is the file tile space
        let playSurfaceEdgeSize: Float = feet * 0.3048
        let wallHeight: Float = 0.05
        let wallThickness: Float = 0.01
        
        
        //var cameraPosition: SIMD3<Float>
        //if let anchorEntity = anchorEntity,
        guard let arv = arView else { return }
        let cameraTransform = arv.cameraTransform
        
        let cameraRawTranslation = arv.cameraTransform.translation
        
        /* CameraEntity - causes the rest of the scene to move relative to camera
         let cameraEntity = AnchorEntity(.camera)
         print("cameraEntity translation: \(cameraEntity.transform.translation) before attaching to AnchorEnity")
         anchorEntity.addChild(cameraEntity)
         print("cameraEntity translation: \(cameraEntity.transform.translation) after attaching to AnchorEnity")
         */
        print("")
        print("arAnchor: \(arAnchor)")
        print("anchorEntity: \(anchorEntity.position)")
        print("anchorEntity relative to world coordinates: \(anchorEntity.position(relativeTo: nil))")  // get as world coordinates
        print("cameraTransform Translation: \(cameraTransform.translation)")
        print("Camera based on arView: \(cameraRawTranslation)")
        
        /*
         print("cameraTranslation relative to anchorEntity: \(cameraTransform.)")
         print("Camera raw translation: \(arv.cameraTransform.translation)")
         print("Camera relative to AE translation: \(cameraPosition.translation)")
         */
        //anchorEntity.transform = cameraTransform
        //anchorEntity.transform.translation =  SIMD3<Float>(x: cameraTransform.translation.x + 0.50, y: anchorEntity.transform.translation.y, z: cameraTransform.translation.z + 0.50) // Keep height the same, move rest to the
        
        let cameraEntity = AnchorEntity(.camera)
        anchorEntity.addChild(cameraEntity)
        let cameraPosition = cameraEntity.position(relativeTo: anchorEntity)
        print("Camera position based on camera entity relative to anchorEntity: \(cameraPosition)")
        
        print("cameraTransform Translation relative to anchorEntity: \(cameraTransform.translation)")
        
        let newCameraPosition = cameraTransform.translation
        
        
        print("AR anchor column 2: \(arAnchor.transform.columns.0)")
        print("AR anchor column 2: \(arAnchor.transform.columns.1)")
        print("AR anchor column 2: \(arAnchor.transform.columns.2)")
        print("AR anchor column 2: \(arAnchor.transform.columns.3)")
        anchorEntity.transform.translation = SIMD3<Float>(x: 0.08, y: 0.0, z: -arAnchor.transform.columns.3.z)
        
        //let cameraPosition = arView.cameraTransform.translation // World coordinators
        
        
        let boxMesh: MeshResource = .generatePlane(width: 1, depth: 1)
        arenaFloorEntity = ModelEntity(mesh: boxMesh)
        var material = SimpleMaterial(color: UIColor.brown.withAlphaComponent(0.5), isMetallic: false)
        //material.roughness = 1.0
        arenaFloorEntity?.model?.materials = [material]
        let size: Float = 1.0
        
        arenaFloorEntity?.physicsBody = PhysicsBodyComponent(massProperties: .default, material: nil, mode: .static)
        arenaFloorEntity?.collision = CollisionComponent(shapes: [.generateBox(width: size, height: 0.001, depth: size)])
        /*
         let floorShape = ShapeResource.generateBox(size: SIMD3<Float>(10.0, 0.01, 10.0))
         var floorPhysicsBody = PhysicsBodyComponent(shapes: [floorShape], mass: .infinity, material: .default, mode: .static)
         let physicsMaterial = PhysicsMaterialResource.generate(friction: 0.1, restitution: 0.0)
         
         // Set the physics material on the physics body component
         floorPhysicsBody.material = physicsMaterial
         */
        //arenaFloorEntity?.components.set(floorPhysicsBody)
        
        
        
        
        //arenaFloorEntity?.physicsBody = PhysicsBodyComponent(massProperties: .default, material: .default, mode: .dynamic)
        //arenaFloorEntity?.collision = CollisionComponent(shapes: [.generateBox(width: size, height: size, depth: size)])
        
        //arenaFloorEntity?.transform.translation =  SIMD3<Float>(x: cameraTransform.translation.x , y:0.0, z: cameraTransform.translation.z ) // Keep height the same, move rest to the
        
        
        let occlusionMesh: MeshResource = .generatePlane(width: 1.2, depth: 1.2)
        let occlusionEntity = ModelEntity(mesh: occlusionMesh)
        var occulusionMaterial = SimpleMaterial(color: UIColor.brown.withAlphaComponent(1.0), isMetallic: false)
        //occulusionMaterial.roughness = 1.0
        occlusionEntity.model?.materials = [occulusionMaterial]
        //anchor.addChild(occlusionEntity)
        
        let spotLight = SpotLight()
        spotLight.light.color = .white
        spotLight.light.intensity = 2500000
        spotLight.light.innerAngleInDegrees = 30
        spotLight.light.outerAngleInDegrees = 50
        spotLight.light.attenuationRadius = 9.0
        spotLight.shadow = SpotLightComponent.Shadow()
        spotLight.position.y = 0.3
        spotLight.orientation = simd_quatf(angle: -.pi/1.5,
                                           axis: [1,0,0])
        
        let lightAnchor = AnchorEntity(world: [0,0,-3])
        lightAnchor.addChild(spotLight)
        arView.scene.anchors.append(lightAnchor)
        
        anchorEntity.addChild(arenaFloorEntity!)
        
        let rightWall = createArenaWallEntityNamed("arenaWall", position: SIMD3<Float>(x: 0.5 + wallThickness / 2, y: wallHeight / 2, z: 0.0), width: wallThickness, depth: 1.0)
        arenaFloorEntity?.addChild(rightWall)
        
        let leftWall = createArenaWallEntityNamed("arenaWall", position: SIMD3<Float>(x: -0.5 - wallThickness / 2, y: wallHeight / 2, z: 0.0), width: wallThickness, depth: 1.0)
        arenaFloorEntity?.addChild(leftWall)
        
        let nearWall = createArenaWallEntityNamed("arenaWall", position: SIMD3<Float>(x: -0.0 , y: wallHeight / 2, z: -0.5 - (wallThickness * 0.50)), width: 1 + (wallThickness * 2), depth: wallThickness)
        arenaFloorEntity?.addChild(nearWall)
        
        let farWall = createArenaWallEntityNamed("arenaWall", position: SIMD3<Float>(x: -0.0 , y: wallHeight / 2, z: 0.5 + (wallThickness * 0.50)), width: 1 + (wallThickness * 2), depth: wallThickness)
        arenaFloorEntity?.addChild(farWall)
        
        func createArenaWallEntityNamed(_ name: String, position: SIMD3<Float>, width: Float, depth: Float) -> ModelEntity {
            
            let wallMesh: MeshResource = .generateBox(width: width, height: wallHeight, depth: depth)
            let wallEntity = ModelEntity(mesh: wallMesh)
            
            var wallMaterial = SimpleMaterial(color: UIColor.blue, isMetallic: true)
            wallMaterial.color =  .init(tint: .blue.withAlphaComponent(1.0), texture: nil)
            wallMaterial.roughness = 0
            wallMaterial.metallic = 1
            // wallMaterial.color.texture = .init(try! .load(named: "grid.png", in: nil))
            wallEntity.model?.materials = [wallMaterial]
            
            let shape = ShapeResource.generateBox(width: width, height: wallHeight, depth: depth)
            wallEntity.collision = CollisionComponent(shapes: [shape])
            wallEntity.physicsBody = PhysicsBodyComponent(
                massProperties: .init(shape: shape, mass: 3),
                material: nil,
                mode: .static
            )
            /*
             wallEntity.components[CollisionComponent.self] = CollisionComponent(
             shapes: [.generateBox(width: width, height: wallHeight, depth: depth)],
             mode: .trigger,
             filter: .sensor
             )
             */
            let newTransform = Transform(translation: position)
            wallEntity.transform = newTransform
            
            /*
             wallEntity.collision = CollisionComponent(shapes: [.generateBox(width: width, height: wallHeight, depth: depth)])
             wallEntity.collision?.grav = true
             wallEntity.collision?.material = .generate(friction: 0.5, restitution: 0.2, density: 1000)
             */
            return wallEntity
        }
        
        
        let scaleFactor: Float = playSurfaceEdgeSize
        let newScale = SIMD3<Float>(x: scaleFactor, y: scaleFactor, z: scaleFactor)
        anchorEntity.transform.scale = newScale
        
        
        arView.session.add(anchor: arAnchor)
        
        
    }
    
    
    private func sendARSessionIDToPeers() {
        let idString = arView.session.identifier.uuidString
        let command = "SessionID:" + idString
        /*
         if let commandData = command.data(using: .utf8) {
         if channels.consumerDevices.count > 0 { print("Sending session ID: \(idString)") }
         channels.sendCollaborationData(commandData)
         }
         */
        channels.annonceSessionID(arView.session.identifier.uuidString)
    }
    
 

    
    //var fpsTimer = Date()
    //var fpsCount = 0
    


    var lastTrackingState: ARCamera.TrackingState?


    // Variables
    //var frameCounter = 0.0
    
    // LAST CHAT APPROACH
    // Constants
    //

    // Transmission rate debug
    var debugFrameCount = 0
    var debugTestTime = Date()
    
    var lastTransimittedImageTime = CACurrentMediaTime()
    var accumulatedTransmissionTime: Double = 0.0
    
    var systemFPSMonitorDisplayFrequency = 1.0 // seconds
    var systemFPSMonitorTimer = Date()
    var systemFPSMonitorCount = 0.0
    
    let statusMapping: [ARFrame.WorldMappingStatus: SystemState.WorldMappingStatus] = [.notAvailable: .notAvailable, .limited: .limited, .extending: .extending, .mapped: .mapped]
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        systemFPSMonitorCount += 1
        if abs(systemFPSMonitorTimer.timeIntervalSinceNow) >= systemFPSMonitorDisplayFrequency {
            let fps = (systemFPSMonitorCount / systemFPSMonitorDisplayFrequency)
            //print("System FPS: \(fps) - Total Frames in \(systemFPSMonitorDisplayFrequency) seconds: \(systemFPSMonitorCount)")
            systemFPSMonitorCount = 0
            systemFPSMonitorTimer = Date()
            SystemState.shared.myDeviceState.fps = Float(fps)
        }
        
        
        let timePerFrame = 1.0 / Double(channels.imageProcessingFPS)
        
        //channels.localDeviceState.worldMappingStatus = frame.worldMappingStatus.rawValue
        if statusMapping[frame.worldMappingStatus] != SystemState.shared.myDeviceState.worldMappingStatus {
            SystemState.shared.myDeviceState.worldMappingStatus = statusMapping[frame.worldMappingStatus]! 
        }
        /*
         switch frame.worldMappingStatus {
         case .extending:
         print("worldMappingStatus: Extending")
         case .notAvailable:
         print("worldMappingStatus: Not Available")
         case .limited:
         print("worldMappingStatus: Limited")
         case .mapped:
         print("worldMappingStatus: Mapped")
         }
         */
        
        
        currentCameraPosition = CGPointMake(CGFloat(arView.cameraTransform.translation.x), CGFloat(arView.cameraTransform.translation.y))
        // print("Camera: x: \(arView.cameraTransform.translation.x), z: \(arView.cameraTransform.translation.x)")
        
        if frame.camera.trackingState != lastTrackingState {
            
            /*
            switch frame.camera.trackingState {
                
            case .notAvailable:
                print("Tracking not available")
            case .limited(let reason):
                print("Tracking limited:")
                switch reason {
                case .excessiveMotion:
                    print("  Too much camera movement")
                case .insufficientFeatures:
                    print("  Insufficient features")
                case .relocalizing:
                    print("  Relocalizing")
                default:
                    print("  Unknown reason")
                }
            case .normal:
                print("TRACKING  NORMAL")
                
            }
             */
        }
        
        let destinationPoint = self.translationFromScreenPoint(point: CGPoint(x: self.arView.bounds.height * 0.50, y: self.arView.bounds.width * 0.50))
        coordinates.text = "(\(String(format: "%.2f", destinationPoint.x)), \(String(format: "%.2f", destinationPoint.y)))"
        
        lastTrackingState = frame.camera.trackingState
        
        // 30 fps: 0.33333
        // Required time interval: 0.03333
        // seconds
        
        let currentTransmissionTime = CACurrentMediaTime()
        let deltaTime = currentTransmissionTime - lastTransimittedImageTime
        lastTransimittedImageTime = currentTransmissionTime
        
        // Add elapsed time to accumulated time
        accumulatedTransmissionTime += deltaTime
        
        // Process frames according to target fps
        if accumulatedTransmissionTime >= timePerFrame {
            
            // Subtract time for processed frame from accumulated time
            accumulatedTransmissionTime -= timePerFrame
            
            //let requiredTimeInterval = (1 / channels.imageProcessingFPS)
            //if abs(fpsTimer.timeIntervalSinceNow) > requiredTimeInterval {
            
            //fpsTimer = Date()
            
            debugFrameCount += 1
            if abs(debugTestTime.timeIntervalSinceNow) > 10 {
                //print("Debug frames processes per sec: \(debugFrameCount / 10)")
                debugFrameCount = 0
                debugTestTime = Date()
            }
            
            if SystemState.shared.myDeviceState.arEnabled {
                //DispatchQueue.main.async {
                let scaleFactor = 0.25
                let devicesRequiringImageFeed = SystemState.shared.devicesRequiringImageFeed()
                if devicesRequiringImageFeed.count > 0 {
                    self.arView.snapshot(saveToHDR: false) { [self] image in
                        if let i = image {
                            if let scaledImage = UIImage.scale(image: i, by: scaleFactor) {
                                if let imageData = scaledImage.jpegData(compressionQuality: 0.0) {
                                    SystemState.shared.myDeviceState.activeImageFeeds = devicesRequiringImageFeed.count
                                    for sourceDevice in devicesRequiringImageFeed {
                                        //print("Sending image feed from \(Common.getHostDevice()) to \(sourceDevice)")
                                        channels.sendContentTypeToSourceDevice(sourceDevice, toServer: false, type: .image, data: imageData)
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
            //}
        }
    }

    
    
    /*
     func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData) {
     //print("Sessiion data")
     
     guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true) else { fatalError("Unexpectedly failed to encode collaboration data.") }
     channels.sendCollaborationData(encodedData)
     
     
     }
     */
    
    override open var shouldAutorotate: Bool {
        return false
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }

    /*
     func startScreenRecording() {
     let captureSession = AVCaptureSession()
     let screenInput = AVCaptureScreenInput(displayID: UIScreen.main)
     let screenInput = AVCaptureScreenInput()
     
     if captureSession.canAddInput(screenInput) {
     captureSession.addInput(screenInput)
     }
     
     let fileOutput = AVCaptureMovieFileOutput()
     if captureSession.canAddOutput(fileOutput) {
     captureSession.addOutput(fileOutput)
     }
     
     captureSession.startRunning()
     let fileName = "aroutput"
     
     do {
     let fileManager = FileManager.default
     
     // Get the documents directory URL
     let documentsDirectory = try fileManager.url(for: .documentDirectory,
     in: .userDomainMask,
     appropriateFor: nil,
     create: false)
     
     // Create the file URL by appending the file name to the documents directory URL
     let fileURL = documentsDirectory.appendingPathComponent(fileName)
     
     // Use the fileURL for any file-related operations
     print("Local file system URL: \(fileURL)")
     
     fileOutput.startRecording(to: fileURL, recordingDelegate: self)
     
     } catch {
     print("Error getting the documents directory URL: \(error)")
     }
     
     }
     */

    
}


extension UIImage {
    class func resize(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        //print("Image size: \(size)")
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    class func scale(image: UIImage, by scale: CGFloat) -> UIImage? {
        let size = image.size
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIImage.resize(image: image, targetSize: scaledSize)
    }
}




extension ARView {
    
    func getImage() -> UIImage? {
        let pixelBuffer = self.session.currentFrame?.capturedImage
        if let pixelBuffer = pixelBuffer {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                return UIImage(cgImage: cgImage)
            } else {
                return nil
            }
        }
        return nil
    }
}



// MARK: - Multipeer Session Functions

extension ViewController {
    
    func initMultipeerSession()
    {
        sessionIDObservation = observe(\.arView.session.identifier, options: [.new]) { object, change in
            print("Current SessionID: \(change.newValue!)")
            guard let multipeerSession = self.multipeerSession else { return }
            let sessionID = change.newValue!.uuidString
            self.channels.annonceSessionID(sessionID)
            self.sendARSessionIDTo(peers: multipeerSession.connectedPeers)
        }
        
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData,
                                            peerJoinedHandler: peerJoined,
                                            peerLeftHandler: peerLeft,
                                            peerDiscoveredHandler: peerDiscovered)
        
        
        guard let multipeerConnectivityService = multipeerSession!.multipeerConnectivityService else {
            fatalError("[FATAL ERROR] Unable to create Sync Service!")
        }
        
        arView.scene.synchronizationService = multipeerConnectivityService
        self.message?.text = "Waiting for peers..."
    }
    
    private func sendARSessionIDTo(peers: [MCPeerID]) {
        guard let multipeerSession = multipeerSession else { return }
        let idString = arView.session.identifier.uuidString
        let command = "SessionID:" + idString
        if let commandData = command.data(using: .utf8) {
            multipeerSession.sendToPeers(commandData, reliably: true, peers: peers)
        }
    }
    
    func receivedData(_ data: Data, from peer: MCPeerID) {
        
    }
    
    func peerDiscovered(_ peer: MCPeerID) -> Bool {
        guard let multipeerSession = multipeerSession else { return false }
        sendMessage("Peer discovered!")
        let sourceDevice = Common.sourceDeviceFromString(deviceName: peer.displayName)
        SystemState.shared.myDeviceState.deviceP2PConnectedStatus = .waiting
        if multipeerSession.connectedPeers.count > 5 {
            sendMessage("[WARNING] Max connections reached!")
            return false
        } else {
            return true
        }
    }
    
    func peerJoined(_ peer: MCPeerID) {
        sendMessage("Hold phones together...")
        connectedSourceDevices.insert(Common.sourceDeviceFromString(deviceName: peer.displayName))
        sendARSessionIDTo(peers: [peer])
        channels.annonceSessionID(arView.session.identifier.uuidString)
        SystemState.shared.myDeviceState.deviceP2PConnectedStatus = .joined
    }
    
    func peerLeft(_ peer: MCPeerID) {
        connectedSourceDevices.remove(Common.sourceDeviceFromString(deviceName: peer.displayName))
        sendMessage("Peer left!")
        peerSessionIDs.removeValue(forKey: peer)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let participantAnchor = anchor as? ARParticipantAnchor {
                channels.annonceSessionID(arView.session.identifier.uuidString)
                let sessionIdentifier = participantAnchor.sessionIdentifier
                AudioServicesPlaySystemSound (1006)
                let anchorEntity = AnchorEntity(anchor: participantAnchor)
                arView.scene.addAnchor(anchorEntity)
                if let sourceDevice = connectedSourceDevicesSessionIDs[sessionIdentifier!.uuidString] {
                    self.message?.text = "\(sourceDevice)"

                } else {
                    fatalError("Could not map AR participant to a device")
                }
            }
        }
    }
}

// MARK: - Helper Functions

extension ViewController {
    
    func sendMessage(_ message: String) {
        DispatchQueue.main.async {
            //self.message?.text = "\(self.connectedSourceDevices)"
            //self.message?.text = message
        }
    }
    
    func removeAnchors() {
        guard let frame = arView.session.currentFrame else { return }
        for anchor in frame.anchors {
            arView.session.remove(anchor: anchor)
        }
        sendMessage("All anchors removed!")
    }
}



extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        
        guard let cgImage = cgImage  else { return nil }
        self.init(cgImage: cgImage)
    }
}

extension MeshResource {
    /**
     Generate three axes of a coordinate system with x axis = red, y axis = green and z axis = blue
     - parameters:
     - axisLength: Length of the axes in m
     - thickness: Thickness of the axes as a percentage of their length
     */
    static func generateCoordinateSystemAxes(length: Float = 0.1, thickness: Float = 2.0) -> Entity {
        let thicknessInM = (length / 100) * thickness
        let cornerRadius = thickness / 2.0
        let offset = length / 2.0
        
        let xAxisBox = MeshResource.generateBox(size: [length, thicknessInM, thicknessInM], cornerRadius: cornerRadius)
        let yAxisBox = MeshResource.generateBox(size: [thicknessInM, length, thicknessInM], cornerRadius: cornerRadius)
        let zAxisBox = MeshResource.generateBox(size: [thicknessInM, thicknessInM, length], cornerRadius: cornerRadius)
        
        let xAxis = ModelEntity(mesh: xAxisBox, materials: [UnlitMaterial(color: .red)])
        let yAxis = ModelEntity(mesh: yAxisBox, materials: [UnlitMaterial(color: .green)])
        let zAxis = ModelEntity(mesh: zAxisBox, materials: [UnlitMaterial(color: .blue)])
        
        xAxis.position = [offset, 0, 0]
        yAxis.position = [0, offset, 0]
        zAxis.position = [0, 0, offset]
        
        let axes = Entity()
        axes.addChild(xAxis)
        axes.addChild(yAxis)
        axes.addChild(zAxis)
        return axes
    }
}

class CommandButton: UIButton  {
    
    public typealias CommandButtonHandler = () -> Void
    var handler: CommandButtonHandler = {}
    
    
}

/*========== Copilot Suggestion 1/2
class DeviceStatusView: UIView {
    
    var deviceStatus: [Common.SourceDevice: DeviceStatus] = [:]
    var deviceStatusLabels: [Common.SourceDevice: UILabel] = [:]
    
    var deviceStatusStackView: UIStackView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDeviceStatusStackView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDeviceStatusStackView()
    }
    
    func setupDeviceStatusStackView() {
        deviceStatusStackView = UIStackView()
        deviceStatusStackView.axis = .horizontal
        deviceStatusStackView.distribution = .fillEqually
        deviceStatusStackView.alignment = .fill
        deviceStatusStackView.spacing = 8.0
        deviceStatusStackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(deviceStatusStackView)
        
        NSLayoutConstraint.activate([
            deviceStatusStackView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            deviceStatusStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            deviceStatusStackView.topAnchor.constraint(equalTo: self.topAnchor),
            deviceStatusStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    func setDeviceStatus(device: Common.SourceDevice, status: DeviceStatus) {
        deviceStatus[device] = status
        if let label = deviceStatusLabels[device] {
            label.text = "\(device): \(status)"
        } else {
            let label = UILabel()
            label.text = "\(device): \(status)"
            deviceStatusLabels[device] = label
            deviceStatusStackView.addArrangedSubview(label)
        }
    }
    
}

*///======== End of Copilot Suggestion
