//
//  DeviceStatusView.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/13/23.
//

import Foundation
import UIKit
import RoverFramework


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
    
}

class DeviceStatusView: UIView {
    
    var worldState = Channels.WorldState() {
        didSet {
            
            for sourceDevice in worldState.devicesState.keys {
                
                let deviceState = worldState.devicesState[sourceDevice]
                
                // Channel
                let label = channelStatusLabels[sourceDevice]
                
                
            }
            
        }
    }
    
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
    var p2pStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var mappingStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var arStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var imageFeedStatusLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    var worldPositionLabels: [SourceDevice: DeviceStatusViewLabel] = [:]
    
    let onboardDevice = Array(Common.shared.devicesWithRole(.onboard))
    let tripodDevice = Array(Common.shared.devicesWithRole(.tripod))
    let controllers = Array(Common.shared.devicesWithRole(.controller))
    var devices: [SourceDevice] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupViews()
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
    
        devices = onboardDevice + tripodDevice + controllers
        let deviceNames = devices.map { device in
            return device.rawValue
        }
        
        backgroundColor = UIColor.lightGray
        rowWidth = self.bounds.width - (rightMargin + leftMargin)

        
        var totalHeight = (rowHeight + rowSpacing) * CGFloat(Common.deviceSet.count) + topMargin + topMargin
        
        deviceNameLabels = addColumn(header: "Device", defaults: deviceNames, width: deviceNameWidth)
        channelStatusLabels = addColumn(header: "Channel", defaults: ["Disconnected"], width: statusLightWidth)
        p2pStatusLabels = addColumn(header: "P2P", defaults: ["Disconnected"], width: statusLightWidth)
        mappingStatusLabels = addColumn(header: "Mapping", defaults: ["None"], width: statusLightWidth)
        arStatusLabels = addColumn(header: "World", defaults: ["Undefined"], width: statusLightWidth)
        imageFeedStatusLabels = addColumn(header: "Video", defaults: ["Disabled"], width: statusLightWidth)
        worldPositionLabels = addColumn(header: "Position", defaults: ["Pending"], width: statusLightWidth)

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
    
    public func setDeviceStatus(device: SourceDevice, status: Channels.DeviceP2PConnectedStatus) {
        
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
                }
            }
        }
    }
    
}
