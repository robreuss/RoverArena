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
            }, completion: { _ in self.alpha = 1.0 })
        } else {
            self.layer.removeAllAnimations()
            alpha = 1.0
        }
    }
    
}

class DeviceStatusView: UIView {
    
    let leftMargin: CGFloat = 4.0
    let rightMargin: CGFloat = 4.0
    let topMargin: CGFloat = 2.0
    let rowSpacing: CGFloat = 1.0
    let columnSpacing: CGFloat = 1.0
    let rowHeight: CGFloat = 25.0
    var rowWidth: CGFloat = 185.0
    var xCursor: CGFloat = 0.0
    
    
    var deviceNameLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var launchDateLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var channelStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var thermalStateLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var batteryStateLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var batteryLevelLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var p2pStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var worldMappingLables: [SourceDevice: DeviceStatusViewLabel] = [:]
    var imageFeedStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var worldPositionLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    
    var fpsLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var arModeLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    
    let hubDevice = Array(Common.shared.devicesWithRole(.hub))
    //let tripodDevice = Array(Common.shared.devicesWithRole(.tripod))
    let controllers = Array(Common.shared.devicesWithRole(.controller))
    var devices: [SourceDevice] = []
    
    var cancellable: AnyCancellable?

    
    func setupState() {
        cancellable = State.shared.$devicesState.sink(receiveValue: { newValue in
            //self.refreshViews() // Handling this with the timer now
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
        
        DispatchQueue.main.async {
            
            for sourceDevice in SourceDevice.allCases {
                
                if let sourceDeviceState = State.shared.devicesState[sourceDevice] {
                    
                    if sourceDeviceState.refreshCount > 0 && sourceDeviceState.sourceDevice != Common.currentDevice() {
                        //print("\(sourceDeviceState.sourceDevice) refresh count: \(sourceDeviceState.refreshCount)")
                    }
                    // Uptime
                    if let launchDateLabel = self.launchDateLabels[sourceDevice] {
                        
                        if let launchDate = sourceDeviceState.launchDate {
                            let elapsedSeconds = round(abs(launchDate.timeIntervalSinceNow))
                            
                            let hours = Int(elapsedSeconds / 3600)
                            let minutes = Int(elapsedSeconds.truncatingRemainder(dividingBy: 3600) / 60)
                            let seconds = Int(elapsedSeconds.truncatingRemainder(dividingBy: 60))
                            /*
                             let seconds = abs(State.shared.currentDeviceState.launchDate.timeIntervalSinceNow)
                             let minutes = abs(Int(seconds / 60))
                             let remainingSeconds = Int(seconds - Double(minutes * 60))
                             let timeString = String(format: "%d:%04.1f", minutes, remainingSeconds)
                             //let timeString = String(format: "%d:%04.1f", minutes, remainingSeconds)
                             */
                            
                            let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                            
                            launchDateLabel.text = "\(timeString)"
                            launchDateLabel.backgroundColor = darkGreen
                        } else {
                            launchDateLabel.text = "~"
                            launchDateLabel.backgroundColor = darkGray
                        }
                        
                    }
                    
                    // Channel
                    if let channelStatusLabel = self.channelStatusLabels[sourceDevice] {
                        channelStatusLabel.text = sourceDeviceState.channelStatus.rawValue
                        switch sourceDeviceState.channelStatus {
                        case .disconnected:
                            channelStatusLabel.backgroundColor = darkGray
                        case .controller:
                            channelStatusLabel.backgroundColor = darkGreen
                        case .hub:
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
                            thermalStateLabel.backgroundColor = darkYellow
                            thermalStateLabel.blink = false
                        case .critical:
                            thermalStateString = "Critical"
                            thermalStateLabel.backgroundColor = darkRed
                            thermalStateLabel.blink = true
                        @unknown default:
                            thermalStateString = "~"
                            thermalStateLabel.backgroundColor = darkGray
                        }
                        if sourceDeviceState.channelStatus == .disconnected {
                            thermalStateString = "~"
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
                            batteryLevelLabel.text = "~"
                        }
                        
                        batteryLevelColor = batteryLevelLabel.backgroundColor!
                        
                    }
                    
                    // Battery State
                    if let batteryStateLabel = self.batteryStateLabels[sourceDevice] {
                        var batteryStateString: String
                        
                        switch sourceDeviceState.batteryState.batteryState {
                        case .unknown:
                            batteryStateString = "~"
                            batteryStateLabel.backgroundColor = darkGray
                            batteryStateLabel.blink = false
                        case .unplugged:
                            batteryStateString = "Battery"
                            batteryStateLabel.backgroundColor = batteryLevelColor
                            batteryStateLabel.blink = false
                        case .charging:
                            batteryStateString = "Charger"
                            batteryStateLabel.backgroundColor = batteryLevelColor
                            batteryStateLabel.blink = false
                        case .full:
                            batteryStateString = "Charger"
                            batteryStateLabel.backgroundColor = darkGreen
                            batteryStateLabel.blink = false
                        @unknown default:
                            batteryStateString = "~"
                            batteryStateLabel.backgroundColor = darkGray
                        }
                        if sourceDeviceState.channelStatus == .disconnected && !sourceDevice.isCurrentDevice() {
                            batteryStateString = "~"
                            batteryStateLabel.backgroundColor = darkGray
                            batteryStateLabel.blink = false
                        }
                        batteryStateLabel.text = batteryStateString
                    }
                    
                    // World mapping
                    if let worldMappingLabel = self.worldMappingLables[sourceDevice] {
                        var worldMappingString: String
                        
                        switch sourceDeviceState.worldMappingStatus {
                        case .notAvailable:
                            worldMappingString = "None"
                            worldMappingLabel.backgroundColor = darkGray
                            worldMappingLabel.blink = false
                        case .limited:
                            worldMappingString = "Limited"
                            worldMappingLabel.backgroundColor = darkYellow
                            worldMappingLabel.blink = false
                        case .extending:
                            worldMappingString = "Extending"
                            worldMappingLabel.backgroundColor = darkYellow
                            worldMappingLabel.blink = false
                        case .mapped:
                            worldMappingString = "Mapped"
                            worldMappingLabel.backgroundColor = darkGreen
                            worldMappingLabel.blink = false
                        @unknown default:
                            worldMappingString = "~"
                            worldMappingLabel.backgroundColor = darkGray
                        }
                        
                        if sourceDeviceState.channelStatus == .disconnected {
                            worldMappingString = "~"
                            worldMappingLabel.backgroundColor = darkGray
                            worldMappingLabel.blink = false
                        } else {
                            worldMappingLabel.text = worldMappingString
                        }
                        
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
                            fpsLevelLabel.text = "~"
                        }
                        
                    }
                    
                    
                    // ARMode
                    if let arModeLabel = self.arModeLabels[sourceDevice] {
                        
                        arModeLabel.text = sourceDeviceState.arMode.rawValue
                        switch sourceDeviceState.arMode {
                            
                        case .none:
                            arModeLabel.backgroundColor = darkGray
                            arModeLabel.blink = false
                            
                        case .full:
                            arModeLabel.backgroundColor = darkBlue
                            arModeLabel.blink = false
                            
                        case .paused:
                            arModeLabel.backgroundColor = darkYellow
                            arModeLabel.blink = false
                            
                        case .positional:
                            arModeLabel.backgroundColor = darkGreen
                            arModeLabel.blink = false
                        }
                        
                        if sourceDeviceState.thermalState.thermalState == .serious {
                            arModeLabel.blink = true
                        }
                        
                        if !sourceDeviceState.sourceDevice.isCurrentDevice() && sourceDeviceState.channelStatus == .disconnected {
                            arModeLabel.backgroundColor = darkGray
                            arModeLabel.text = "~"
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
                            p2pStatusLabel.text = "~"
                            
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
                            p2pStatusLabel.text = "~"
                            
                        }
                        
                    }
                    
                    
                }
                
            }
        }
        
    }
    
    private func addColumn(header: String, defaults: [String], sampleTextForWidth: String) -> [SourceDevice: DeviceStatusViewLabel] {
        
        let headerLabel = DeviceStatusViewLabel(frame: CGRectMake(xCursor, 0.0, 1.0, rowHeight))
        headerLabel.text = sampleTextForWidth
        addSubview(headerLabel)
        
        let columnPadding = 18.0
        //let rowPadding = 3.0
        let size = headerLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: rowHeight))
        let columnWidth = size.width + columnPadding
        headerLabel.frame = CGRectMake(xCursor, 0.0, columnWidth, rowHeight)
        headerLabel.text = header
        
        var labelDictionary: [SourceDevice: DeviceStatusViewLabel] = [:]
        for device in devices {
            if let index = devices.firstIndex(of: device) {
                
                let yPosition = topMargin + (rowHeight + rowSpacing) * (CGFloat(index) + 1.0) // Plus one for the header
                
                let label = DeviceStatusViewLabel(frame: CGRectMake(xCursor, yPosition, columnWidth, rowHeight))
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
        xCursor = xCursor + columnWidth + columnSpacing
        return labelDictionary
    }
    
    private func setupViews() {
        
        
        let _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.refreshViews()
        }
        
        
        devices = hubDevice + [.iPhone14ProMax, .iPhone12Pro, .iPhoneXSMax]
        //devices = hubDevice + tripodDevice + controllers
        let deviceNames = devices.map { device in
            return device.rawValue
        }
        
        backgroundColor = UIColor.clear
        rowWidth = self.bounds.width - (rightMargin + leftMargin)
        
        let totalHeight = (rowHeight + rowSpacing) * CGFloat(Common.deviceSet.count) + topMargin + topMargin
        
        deviceNameLabels = addColumn(header: "Device", defaults: deviceNames, sampleTextForWidth: "iPhone14ProMax")
        launchDateLabels = addColumn(header: "Uptime", defaults: ["~"], sampleTextForWidth: "Runtime")
        channelStatusLabels = addColumn(header: "Channel", defaults: ["~"], sampleTextForWidth: "Controller")
        
        batteryLevelLabels = addColumn(header: "Power", defaults: ["~"], sampleTextForWidth: "Power")
        batteryStateLabels = addColumn(header: "Source", defaults: ["~"], sampleTextForWidth: "Charging")
        thermalStateLabels = addColumn(header: "Thermal", defaults: ["~"], sampleTextForWidth: "Nominal")
        arModeLabels = addColumn(header: "AR Mode", defaults: ["~"], sampleTextForWidth: "Positional")
        
        worldMappingLables = addColumn(header: "Mapping", defaults: ["~"], sampleTextForWidth: "Not available")
        imageFeedStatusLabels = addColumn(header: "Video", defaults: ["~"], sampleTextForWidth: "Feeding")
        p2pStatusLabels = addColumn(header: "P2P", defaults: ["~"], sampleTextForWidth: "Connected")
        
        //arStatusLabels = addColumn(header: "World", defaults: ["Disconnected"], width: statusLightWidth)
        
        fpsLabels = addColumn(header: "FPS", defaults: ["0.0"], sampleTextForWidth: "FPS")
        worldPositionLabels = addColumn(header: "Position", defaults: ["~"], sampleTextForWidth: "Position")
        
        frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, totalHeight)
        
    }
    
    
}
