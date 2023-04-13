//
//  Frame.swift
//  RoverArena
//
//  Created by Rob Reuss on 4/9/23.
//

import Foundation
import UIKit
import ARKit


 /*
class Frame {
    
    func deserializeARFrame(_ data: Data) -> ARFrame? {
        var dataBytes = [UInt8](data)
        
        // Deserialize camera transform
        let cameraTransformDataLength = MemoryLayout<simd_float4x4>.stride
        guard dataBytes.count >= cameraTransformDataLength else { return nil }
        let cameraTransformData = dataBytes[..<cameraTransformDataLength]
        dataBytes.removeFirst(cameraTransformDataLength)
        let cameraTransform = UnsafeMutableRawPointer(mutating: cameraTransformData).load(as: simd_float4x4.self)
        let camera = ARCamera(transform: cameraTransform)
        
        // Deserialize frame data
        let frameDataLength = MemoryLayout<ARFrame.Metadata>.stride
        guard dataBytes.count >= frameDataLength else { return nil }
        let frameData = dataBytes[..<frameDataLength]
        dataBytes.removeFirst(frameDataLength)
        var frame = ARFrame()
        frame.metadata = UnsafeMutableRawPointer(mutating: frameData).load(as: ARFrame.Metadata.self)
        
        // Deserialize captured image
        let pixelBufferInfoDataLength = MemoryLayout<PixelBufferInfo>.stride
        guard dataBytes.count >= pixelBufferInfoDataLength else { return nil }
        let pixelBufferInfoData = dataBytes[..<pixelBufferInfoDataLength]
        dataBytes.removeFirst(pixelBufferInfoDataLength)
        guard let pixelBufferInfo = deserializePixelBufferInfo(pixelBufferInfoData) else { return nil }
        let pixelBufferLengthDataLength = MemoryLayout<UInt32>.stride
        guard dataBytes.count >= pixelBufferLengthDataLength else { return nil }
        let pixelBufferLengthData = dataBytes[..<pixelBufferLengthDataLength]
        dataBytes.removeFirst(pixelBufferLengthDataLength)
        let pixelBufferLength = UnsafeMutableRawPointer(mutating: pixelBufferLengthData).load(as: UInt32.self)
        guard dataBytes.count >= pixelBufferLength else { return nil }
        let pixelBufferData = dataBytes[..<Int(pixelBufferLength)]
        dataBytes.removeFirst(Int(pixelBufferLength))
        let pixelBuffer = pixelBufferFromData(pixelBufferData, width: pixelBufferInfo.width, height: pixelBufferInfo.height, format: pixelBufferInfo.format)
        
        // Deserialize estimated depth data
        var depthPixelBuffer: CVPixelBuffer?
        var depthData: Data?
        var depthInfo: PixelBufferInfo?
        if !dataBytes.isEmpty {
            let depthInfoDataLength = MemoryLayout<PixelBufferInfo>.stride
            guard dataBytes.count >= depthInfoDataLength else { return nil }
            let depthInfoData = dataBytes[..<depthInfoDataLength]
            dataBytes.removeFirst(depthInfoDataLength)
            guard let depthPixelBufferInfo = deserializePixelBufferInfo(depthInfoData) else { return nil }
            let depthPixelBufferLengthDataLength = MemoryLayout<UInt32>.stride
            guard dataBytes.count >= depthPixelBufferLengthDataLength else { return nil }
            let depthPixelBufferLengthData = dataBytes[..<depthPixelBufferLengthDataLength]
            dataBytes.removeFirst(depthPixelBufferLengthDataLength)
            let depthPixelBufferLength = UnsafeMutableRawPointer(mutating: depthPixelBufferLengthData).load(as: UInt32.self)
            guard dataBytes.count >= depthPixelBufferLength else { return nil }
            let depthPixelBufferData = dataBytes[..<Int(depthPixelBufferLength)]
            dataBytes.removeFirst(Int(depthPixelBufferLength))
            depthPixelBuffer = pixelBufferFromData(depthPixelBufferData, width: depthPixelBufferInfo.width, height: depthPixelBufferInfo.height, format: depthPixelBuffer)
        }
        // Construct ARFrame from deserialized components
        frame.camera = camera
        frame.capturedImage = pixelBuffer
        frame.rawDepthData = depthData
        frame.estimatedDepthData = depthPixelBuffer
        frame.estimatedDepthDataInfo = depthInfo
        return frame
    }
    
    func deserializePixelBufferInfo(_ data: Data) -> PixelBufferInfo? {
        var dataBytes = [UInt8](data)
        guard dataBytes.count >= MemoryLayout<PixelBufferInfo>.stride else { return nil }
        let pixelBufferInfoData = dataBytes[..<MemoryLayout<PixelBufferInfo>.stride]
        let pixelBufferInfo = UnsafeMutableRawPointer(mutating: pixelBufferInfoData).load(as: PixelBufferInfo.self)
        return pixelBufferInfo
    }
                                                   
                                                   
    func pixelBuffer(from jpegData: Data) -> CVPixelBuffer? {
        guard let image = UIImage(data: jpegData) else {
            return nil
        }
        
        let ciImage = CIImage(image: image)
        let ciContext = CIContext()
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        
        if status != kCVReturnSuccess {
            return nil
        }
        
        ciContext.render(ciImage!, to: pixelBuffer!)
        
        return pixelBuffer
    }
    
    func deserializePixelBuffer(from data: Data) -> CVPixelBuffer? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        
        let ciImage = CIImage(image: image)
        let ciContext = CIContext()
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        
        if status != kCVReturnSuccess {
            return nil
        }
        
        ciContext.render(ciImage!, to: pixelBuffer!)
        
        return pixelBuffer
    }

    
}

*/
