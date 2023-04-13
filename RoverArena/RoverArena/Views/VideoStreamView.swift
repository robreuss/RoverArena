//
//  VideoStreamView.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/15/23.
//

import Foundation
import UIKit
import RoverFramework
import RealityKit
import UniformTypeIdentifiers

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
    
    func pixelBuffer(pixelBuffer: CVPixelBuffer) {
        
        if let image = convertPixelBufferToUIImage(pixelBuffer) {
            self.image = image
        } else {
            fatalError("CVPixelBuffer to UIImage failure")
        }
       
    }
    
    required override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setup()

    }
    
    func setup() {
        
        backgroundColor = UIColor.lightGray
        
        let sourceLabelHeight: CGFloat = 25.0
        imageView.frame = CGRectMake(0.0, 0.0, bounds.width, bounds.height)
        addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.clear
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: self.topAnchor, constant: sourceLabelHeight),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        videoSourceLabel.backgroundColor = darkGray
        videoSourceLabel.frame = CGRectMake(0.0, 0.0, bounds.width, sourceLabelHeight)
        videoSourceLabel.font = UIFont.systemFont(ofSize: 12)
        videoSourceLabel.text = videoSourceText
        videoSourceLabel.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        addSubview(videoSourceLabel)
        NSLayoutConstraint.activate([
            videoSourceLabel.widthAnchor.constraint(equalTo: self.widthAnchor)
        ])
    }
    
    func reset() {
        videoSourceLabel.text = "  \(videoSourceText)"
        imageView.image = UIImage()
    }
    
    func convertPixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Create a CIContext and convert the CIImage to a CGImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // Create a UIImage from the CGImage
        let uiImage = UIImage(cgImage: cgImage)
        
        return uiImage
    }

    func pixelBufferToJPEG(pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Calculate the aspect ratio of the pixel buffer
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bufferAspectRatio = CGFloat(bufferWidth) / CGFloat(bufferHeight)
        
        // Set the output size to preserve the aspect ratio
        let outputWidth = CGFloat(min(bufferWidth, bufferHeight))
        let outputHeight = outputWidth / bufferAspectRatio
        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
                return nil
            }
            let properties: [CFString: Any] = [
                kCGImageDestinationImageMaxPixelSize: outputSize.width
            ]
            CGImageDestinationSetProperties(destination, properties as CFDictionary)
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else {
                return nil
            }
            return data as Data
        }
        return nil
    }
    
}
