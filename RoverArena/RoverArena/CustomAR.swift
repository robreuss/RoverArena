//
//  CustomAR.swift
//  RoverArena
//
//  Created by Rob Reuss on 4/6/23.
//

import Foundation
import ARKit
import UIKit
import RealityKit


/*
struct SerializedAnchor {
    let anchor: ARAnchor
    let shape: Shape
    let material: Material
    let physicsBody: PhysicsBody?
}

enum Shape: Codable {
    case box(size: SIMD3<Float>)
    case sphere(radius: Float)
    // Add more shapes as needed
}

struct Material: Codable {
    let color: UIColor
    let isMetallic: Bool
}


struct PhysicsProperties: Codable {
    let mass: Float
    let material: PhysicsMaterial
    let mode: PhysicsBodyMode
}
 */


struct SerializedARFrame {
    let capturedImage: Data
    let cameraTransform: simd_float4x4
    //let serializedAnchors: [SerializedAnchor]
}

extension UIViewController {
    
    func serializeARFrame(arFrame: ARFrame) -> SerializedARFrame? {
        
        /*
        guard let capturedImageBuffer = arFrame.capturedImage else {
            print("Failed to get captured image buffer.")
            return nil
        }
        */
        
        guard let capturedImage = UIImage(pixelBuffer: arFrame.capturedImage) else {
            print("Failed to create UIImage from pixel buffer.")
            return nil
        }
        
        guard let capturedImageData = capturedImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert UIImage to JPEG data.")
            return nil
        }
        
        let cameraTransform = arFrame.camera.transform
        
        return SerializedARFrame(capturedImage: capturedImageData, cameraTransform: cameraTransform)
    }
}


extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
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
