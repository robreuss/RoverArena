//
//  VideoStreamView.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/15/23.
//

import Foundation
import UIKit
import RoverFramework

@IBDesignable
class VideoStreamView: UIView {
    
    var image = UIImage() {
        didSet(newValue) {
            imageView.image = newValue
        }
    }
    
    var imageView = UIImageView()
    var videoSourceLabel = UILabel()
    var videoSourceDevice: SourceDevice = .none {
        didSet {
            reset()
        }
    }
    
    var videoSourceText: String {
        get {
            if let role = Common.shared.deviceRoles[videoSourceDevice] {
                return "\(videoSourceDevice.rawValue) (\(role.rawValue))"
            } else {
                return "No video feed source"
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setup()

    }
    
    func setup() {
        
        imageView.frame = CGRectMake(0.0, 0.0, bounds.width, bounds.height)
        addSubview(imageView)
        imageView.backgroundColor = UIColor.clear
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        videoSourceLabel.backgroundColor = UIColor.yellow
        videoSourceLabel.frame = CGRectMake(0.0, 0.0, 250, 25)
        videoSourceLabel.font = UIFont.systemFont(ofSize: 10)
        videoSourceLabel.text = videoSourceText
        videoSourceLabel.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        addSubview(videoSourceLabel)
    }
    
    func reset() {
        videoSourceLabel.text = videoSourceText
        imageView.image = UIImage()
    }
    
}
