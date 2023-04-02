//
//  DeviceStatusView.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/13/23.
//

import Foundation
import UIKit
import RoverFramework
import Combine

// Columns
// Device Name
// Channel status
// P2P status
// Mapping status
// AR status (Off, Building, Joined)
// Image feed (device count)


let darkRed = UIColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1.0)
let darkYellow = UIColor(red: 0.7, green: 0.5, blue: 0.0, alpha: 1.0)
let darkGreen = UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1.0)
let grayWhite = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
let darkGray = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.9)


class DeviceStatusViewLabel: UILabel {
    
    func configure() {
        backgroundColor = darkGray
        textColor = grayWhite
        text = "Unset"
        textAlignment = .center
        font = UIFont.systemFont(ofSize: 12)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    var labelText: String = "~" {
        didSet {
            text = labelText
            refreshBlink()
        }
    }
    
    var blink: Bool = false {
        didSet {
            refreshBlink()
        }
    }
    
    func refreshBlink() {
        if blink {
            UIView.animate(withDuration: 0.7, delay: 0.0, options: [.autoreverse, .repeat], animations: {
                self.alpha = 0.7
            }, completion: nil)
        } else {
            self.layer.removeAllAnimations()
            alpha = 1.0
        }
    }
    
}

class DeviceStatusView: UIView {
    
    /*
    var state = SystemState() {
        didSet {
            
            for sourceDevice in devicesState.keys {
                
                let deviceState = devicesState[sourceDevice]
                
                // Channel
                let label = channelStatusLabels[sourceDevice]
                label?.text = deviceState?.channelStatus.rawValue
                
            }
            
        }
    }
    */

    
    let leftMargin: CGFloat = 4.0
    let rightMargin: CGFloat = 4.0
    let topMargin: CGFloat = 4.0
    let rowSpacing: CGFloat = 1.0
    let columnSpacing: CGFloat = 1.0
    let rowHeight: CGFloat = 25.0
    var rowWidth: CGFloat = 185.0
    var xCursor: CGFloat = 0.0
    

    var deviceNameLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var channelStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var thermalStateLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var batteryStateLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var batteryLevelLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var p2pStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var mappingStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var imageFeedStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var worldPositionLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    
    var fpsLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var arEnabledLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
  
    let hubDevice = Array(Common.shared.devicesWithRole(.hub))
    //let tripodDevice = Array(Common.shared.devicesWithRole(.tripod))
    let controllers = Array(Common.shared.devicesWithRole(.controller))
    var devices: [SourceDevice] = []
    
    var cancellable: AnyCancellable?

    /*
    let cancellable = SystemState.shared.$devicesState.sink { newValue in
        refreshViews()
        print("myProperty has changed to: \(newValue)")
    }
     */
    
    func setupState() {
        cancellable = State.shared.$devicesState.sink(receiveValue: { newValue in
            self.refreshViews()
        })
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupState()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupViews()
        setupState()
    }
    
    private func refreshViews() {
        
        print("Refreshing status views")
        
        DispatchQueue.main.async {
            
            for sourceDevice in SourceDevice.allCases {
                
                if let sourceDeviceState = State.shared.devicesState[sourceDevice] {
                    
                    // Channel
                    if let channelStatusLabel = self.channelStatusLabels[sourceDevice] {
                        channelStatusLabel.text = sourceDeviceState.channelStatus.rawValue
                        switch sourceDeviceState.channelStatus {
                        case .disconnected:
                            channelStatusLabel.backgroundColor = darkGray
                        case .consumer:
                            channelStatusLabel.backgroundColor = darkGreen
                        case .server:
                            channelStatusLabel.backgroundColor = darkGreen
                        }
                    }
                    
                    // Thermal
                    if let thermalStateLabel = self.thermalStateLabels[sourceDevice] {
                        var thermalStateString: String
                        
                        switch sourceDeviceState.thermalState.thermalState {
                        case .nominal:
                            thermalStateString = "Nominal"
                            thermalStateLabel.backgroundColor = darkGreen
                            thermalStateLabel.blink = false
                        case .fair:
                            thermalStateString = "Fair"
                            thermalStateLabel.backgroundColor = darkYellow
                            thermalStateLabel.blink = false
                        case .serious:
                            thermalStateString = "Serious"
                            thermalStateLabel.backgroundColor = darkRed
                            thermalStateLabel.blink = false
                        case .critical:
                            thermalStateString = "Critical"
                            thermalStateLabel.backgroundColor = darkRed
                            thermalStateLabel.blink = true
                        @unknown default:
                            thermalStateString = "Unknown"
                            thermalStateLabel.backgroundColor = darkGray
                        }
                        if sourceDeviceState.channelStatus == .disconnected {
                            thermalStateString = "Unknown"
                            thermalStateLabel.backgroundColor = darkGray
                            thermalStateLabel.blink = false
                        }
                        thermalStateLabel.text = thermalStateString
                    }
                    
                    
                    // Battery Level
                    var batteryLevelColor = darkGray
                    if let batteryLevelLabel = self.batteryLevelLabels[sourceDevice] {
                        
                        let batteryLevelInt = Int(sourceDeviceState.batteryLevel * 100.0)
                        
                        batteryLevelLabel.text = "\(batteryLevelInt)%"
                        //print("\(sourceDevice), Battery level: \(batteryLevelInt), float: \(sourceDeviceState.batteryLevel)")
                        switch batteryLevelInt {
                            
                        case -1:
                            batteryLevelLabel.backgroundColor = darkRed
                            batteryLevelLabel.blink = true
                            batteryLevelLabel.text = "Not enabled"
                        case 1..<4:
                            batteryLevelLabel.backgroundColor = darkGreen
                            batteryLevelLabel.blink = false
                        case 4..<25:
                            batteryLevelLabel.backgroundColor = darkRed
                            batteryLevelLabel.blink = true
                        case 25..<40:
                            batteryLevelLabel.backgroundColor = darkRed
                            batteryLevelLabel.blink = false
                        case 40..<75:
                            batteryLevelLabel.backgroundColor = darkYellow
                            batteryLevelLabel.blink = false
                        case 75...100:
                            batteryLevelLabel.backgroundColor = darkGreen
                            batteryLevelLabel.blink = false
                        default:
                            batteryLevelLabel.backgroundColor = darkGray
                            batteryLevelLabel.blink = false
                            batteryLevelLabel.text = "Unknown"
                        }
                        
                        batteryLevelColor = batteryLevelLabel.backgroundColor!
                        
                    }
                    
                    // Battery State
                    if let batteryStateLabel = self.batteryStateLabels[sourceDevice] {
                        var batteryStateString: String
                        
                        switch sourceDeviceState.batteryState.batteryState {
                        case .unknown:
                            batteryStateString = "Unknown"
                            batteryStateLabel.backgroundColor = darkGray
                            batteryStateLabel.blink = false
                        case .unplugged:
                            batteryStateString = "Unplugged"
                            batteryStateLabel.backgroundColor = batteryLevelColor
                            batteryStateLabel.blink = false
                        case .charging:
                            batteryStateString = "Charging"
                            batteryStateLabel.backgroundColor = batteryLevelColor
                            batteryStateLabel.blink = false
                        case .full:
                            batteryStateString = "Full"
                            batteryStateLabel.backgroundColor = darkGreen
                            batteryStateLabel.blink = false
                        @unknown default:
                            batteryStateString = "Unknown"
                            batteryStateLabel.backgroundColor = darkGray
                        }
                        if sourceDeviceState.channelStatus == .disconnected && !sourceDevice.isCurrentDevice() {
                            batteryStateString = "Unknown"
                            batteryStateLabel.backgroundColor = darkGray
                            batteryStateLabel.blink = false
                        }
                        batteryStateLabel.text = batteryStateString
                    }

                    
                    // FPS
                    if let fpsLevelLabel = self.fpsLabels[sourceDevice] {
                        
                        let fps = Int(sourceDeviceState.fps)
                        fpsLevelLabel.text = "\(fps)"
                        switch fps {
                            
                        case 0..<1:
                            fpsLevelLabel.backgroundColor = darkGray
                            fpsLevelLabel.blink = false
                            fpsLevelLabel.text = "~"
                            
                        case 1..<15:
                            fpsLevelLabel.backgroundColor = darkRed
                            fpsLevelLabel.blink = true
                        case 15..<30:
                            fpsLevelLabel.backgroundColor = darkRed
                            fpsLevelLabel.blink = false
                        case 30..<60:
                            fpsLevelLabel.backgroundColor = darkYellow
                            fpsLevelLabel.blink = false
                        case 60..<75:
                            fpsLevelLabel.backgroundColor = darkGreen
                            fpsLevelLabel.blink = false
                        default:
                            fpsLevelLabel.backgroundColor = darkGray
                            fpsLevelLabel.blink = false
                            fpsLevelLabel.text = "0.0"
                        }
                        
                    }
                    
                    
                    // AREnabled
                    if let arEnabledLabel = self.arEnabledLabels[sourceDevice] {
                        
                        arEnabledLabel.text = sourceDeviceState.arEnabled ? "Yes" : "No"
                        
                        if sourceDeviceState.arEnabled {
                            arEnabledLabel.backgroundColor = darkGreen
                        } else {
                            arEnabledLabel.backgroundColor = darkRed
                        }
                        
                        if !sourceDeviceState.sourceDevice.isCurrentDevice() && sourceDeviceState.channelStatus == .disconnected {
                            arEnabledLabel.backgroundColor = darkGray
                            arEnabledLabel.text = "Disconnected"
                        }
                        
                    }
                    
                    // P2P status
                    if let p2pStatusLabel = self.p2pStatusLabels[sourceDevice] {
                        
                        switch sourceDeviceState.deviceP2PConnectedStatus {
                            
                        case .waiting:
                            p2pStatusLabel.backgroundColor = darkYellow
                            p2pStatusLabel.blink = false
                            p2pStatusLabel.text = "Waiting"
                            
                        case .unknown:
                            p2pStatusLabel.backgroundColor = darkGray
                            p2pStatusLabel.blink = false
                            p2pStatusLabel.text = "Unknown"
                            
                        case .joined:
                            p2pStatusLabel.backgroundColor = darkGreen
                            p2pStatusLabel.blink = false
                            p2pStatusLabel.text = "Joined"
                            
                        case .connected:
                            p2pStatusLabel.backgroundColor = darkGreen
                            p2pStatusLabel.blink = false
                            p2pStatusLabel.text = "Connected"
                            
                        case .disconnected:
                            p2pStatusLabel.backgroundColor = darkRed
                            p2pStatusLabel.blink = true
                            p2pStatusLabel.text = "Disconnected"
                            
                        }
                        
                    }

                    
                }
                
            }
        }
        
    }
    
    private func addColumn(header: String, defaults: [String], width: CGFloat) -> [SourceDevice: DeviceStatusViewLabel] {
        
        let headerLabel = DeviceStatusViewLabel(frame: CGRectMake(xCursor, 0.0, width, rowHeight))
        headerLabel.text = header
        addSubview(headerLabel)
        
        var labelDictionary: [SourceDevice: DeviceStatusViewLabel] = [:]
        for device in devices {
            if let index = devices.firstIndex(of: device) {
                
                let yPosition = topMargin + (rowHeight + rowSpacing) * (CGFloat(index) + 1.0) // Plus one for the header
                
                let label = DeviceStatusViewLabel(frame: CGRectMake(xCursor, yPosition, width, rowHeight))
                addSubview(label)
                
                labelDictionary[device] = label
                
                if defaults.count == 0 {
                    label.text = "Default"
                } else if defaults.count == 1 {
                    label.text = defaults[0]
                } else {
                    label.text = defaults[index]
                }
               
            }
        }
        xCursor = xCursor + width + columnSpacing
        return labelDictionary
    }
    
    private func setupViews() {
        
        let statusLightWidth: CGFloat = 90.0
        let deviceNameWidth: CGFloat = 175.0

        devices = hubDevice + [.iPhone14ProMax, .iPhone12Pro, .iPhoneXSMax]
        //devices = hubDevice + tripodDevice + controllers
        let deviceNames = devices.map { device in
            return device.rawValue
        }
        
        backgroundColor = UIColor.black
        rowWidth = self.bounds.width - (rightMargin + leftMargin)

        var totalHeight = (rowHeight + rowSpacing) * CGFloat(Common.deviceSet.count) + topMargin + topMargin
        
        deviceNameLabels = addColumn(header: "Device", defaults: deviceNames, width: deviceNameWidth)
        channelStatusLabels = addColumn(header: "Channel", defaults: ["Disconnected"], width: statusLightWidth)
        thermalStateLabels = addColumn(header: "Thermal", defaults: ["Disconnected"], width: statusLightWidth)
        batteryStateLabels = addColumn(header: "Power State", defaults: ["Disconnected"], width: statusLightWidth)
        batteryLevelLabels = addColumn(header: "Power Level", defaults: ["Disconnected"], width: statusLightWidth)
        imageFeedStatusLabels = addColumn(header: "Video", defaults: ["Disabled"], width: statusLightWidth)
        p2pStatusLabels = addColumn(header: "P2P", defaults: ["Disconnected"], width: statusLightWidth)
        mappingStatusLabels = addColumn(header: "Mapping", defaults: ["None"], width: statusLightWidth)
        //arStatusLabels = addColumn(header: "World", defaults: ["Disconnected"], width: statusLightWidth)
        arEnabledLabels = addColumn(header: "Rendering", defaults: ["No"], width: statusLightWidth)
        fpsLabels = addColumn(header: "FPS", defaults: ["0.0"], width: statusLightWidth)
        worldPositionLabels = addColumn(header: "Position", defaults: ["Disconnected"], width: statusLightWidth)


        /*
         for device in devices {
         if let index = devices.firstIndex(of: device) {
         
         let yPosition = topMargin + (rowHeight + rowSpacing) * CGFloat(index)
         let statusLightView = UILabel(frame: CGRectMake(leftMargin, yPosition, statusLightWidth, rowHeight))
         statusLightView.backgroundColor = darkRed
         statusLightView.textColor = grayWhite
         statusLightView.text = "Unknown"
         statusLightView.textAlignment = .center
         statusLightView.font = UIFont.systemFont(ofSize: 12)
         addSubview(statusLightView)
         p2pLabels.append(statusLightView)
         
         let deviceNameLabel = UILabel(frame: CGRectMake(leftMargin + statusLightWidth + rowSpacing, yPosition, deviceNameWidth, rowHeight))
         deviceNameLabel.backgroundColor = UIColor.darkGray
         deviceNameLabel.textColor = grayWhite
         deviceNameLabel.font = UIFont.systemFont(ofSize: 12)
         deviceNameLabel.adjustsFontSizeToFitWidth = true
         addSubview(deviceNameLabel)
         
         if let deviceRole = Common.shared.deviceRoles[device]?.rawValue {
         deviceNameLabel.text = "    \(device.rawValue) (\(deviceRole))"
         }
         
         
         let deviceRoleLabel = UILabel(frame: CGRectMake(leftMargin + statusLightWidth +  rowSpacing + deviceNameWidth + rowSpacing, yPosition, deviceRoleWidth, rowHeight))
         deviceRoleLabel.backgroundColor = UIColor.darkGray
         deviceRoleLabel.textColor = grayWhite
         deviceRoleLabel.font = UIFont.systemFont(ofSize: 12)
         deviceRoleLabel.adjustsFontSizeToFitWidth = true
         //addSubview(deviceRoleLabel)
         
         if let deviceRole = Common.shared.deviceRoles[device]?.rawValue {
         deviceRoleLabel.text = "  \(deviceRole)"
         }
         
         
         }
         */
        frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, totalHeight)
        
    }
    
    
    public func addDeviceList() {
        
        
    }
    
    /*
    public func setDeviceStatus(device: SourceDevice, status: SystemState.DeviceP2PConnectedStatus) {
        
        if let index = devices.firstIndex(of: device) {
            
            if let statusLightView = p2pStatusLabels[device] {

                statusLightView.text = "\(status.rawValue)"
                
                switch status {
                case .disconnected:
                    statusLightView.backgroundColor = darkRed
                case .connected:
                    statusLightView.backgroundColor = darkYellow
                case .waiting:
                    statusLightView.backgroundColor = darkYellow
                case .joined:
                    statusLightView.backgroundColor = darkGreen
                case .unknown:
                    statusLightView.backgroundColor = UIColor.clear
                }
            }
        }
    }
     */
    
}
