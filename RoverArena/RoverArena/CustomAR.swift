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
import simd

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


/*
 REQUIRED ARFRAME PROPERTIES
 
 light estimate
 anchors, anchor.transform
 capturedimage
 displayTransform - I think this is a method
 
 */



/*

struct EncodableFloat4x4: Codable {
    var elements: [Float]

    init(matrix: simd_float4x4) {
        elements = []
        for i in 0..<4 {
            for j in 0..<4 {
                elements.append(matrix[i][j])
            }
        }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Float] = []
        while !container.isAtEnd {
            let element = try container.decode(Float.self)
            elements.append(element)
        }
        guard elements.count == 16 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid matrix data")
        }
        self.elements = elements
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in elements {
            try container.encode(element)
        }
    }

    var matrix: simd_float4x4 {
        var matrix = simd_float4x4()
        var index = 0
        for i in 0..<4 {
            for j in 0..<4 {
                matrix[i][j] = elements[index]
                index += 1
            }
        }
        return matrix
    }
}

extension UIViewController {
    
    struct ARFrameProperties: Encodable {
        let cameraTransform: EncodableFloat4x4
        let cameraProjectionMatrix: EncodableFloat4x4
        let lightEstimate: EncodableARLightEstimate?
    }



    func encodeARFrameProperties(arFrame: ARFrame) throws -> Data {
        let cameraTransform = arFrame.camera.transform
        let encodableCameraTransform = EncodableFloat4x4(matrix: cameraTransform)

        let cameraProjectionMatrix = arFrame.camera.projectionMatrix
        let encodableCameraProjectionMatrix = EncodableFloat4x4(matrix: cameraProjectionMatrix)
        
        let lightEstimate = arFrame.lightEstimate
        let encodableLightEstimate = EncodableARLightEstimate(from: lightEstimate)

        let arFrameProperties = ARFrameProperties(cameraTransform: encodableCameraTransform,
                                                  cameraProjectionMatrix: encodableCameraProjectionMatrix, lightEstimate: encodableLightEstimate)

        let jsonData = try JSONEncoder().encode(arFrameProperties)
        return jsonData
    }
    
    struct EncodableARLightEstimate: Codable {
        let ambientIntensity: CGFloat
        let ambientColorTemperature: CGFloat

        init(from lightEstimate: ARLightEstimate?) {
            self.ambientIntensity = lightEstimate?.ambientIntensity ?? 0.0
            self.ambientColorTemperature = lightEstimate?.ambientColorTemperature ?? 0.0
        }
    }

    func encodeARLightEstimate(arLightEstimate: ARLightEstimate) throws -> Data {
        let encodableARLightEstimate = EncodableARLightEstimate(from: arLightEstimate)
        let jsonData = try JSONEncoder().encode(encodableARLightEstimate)
        return jsonData
    }
    
    
    func decodeARFrameAnchors(from data: Data) throws -> [ARAnchor] {
        
        let decoder = JSONDecoder()
        let encodableFrameAnchors = try decoder.decode(EncodableARFrameAnchors.self, from: data)
        let anchors = encodableFrameAnchors.anchors.map { encodableAnchor -> ARAnchor in
            switch encodableAnchor.type {
            case .anchor:
                let anchor = ARAnchor(name: "MyAnchorName", transform: encodableAnchor.transform.matrix)
                //anchor.identifier.uuid = encodableAnchor.identifier
                return ARAnchor(transform: encodableAnchor.transform.matrix)
            case .planeAnchor:
                let planeAnchor = ARPlaneAnchor(transform: encodableAnchor.transform.matrix)
                
                planeAnchor.center = encodableAnchor.center
                planeAnchor.extent = encodableAnchor.extent
                 
                return planeAnchor
            }
        }
        return anchors
    }
    
    struct EncodableARAnchor: Codable {
        enum AnchorType: Codable {
            case anchor
            case planeAnchor
        }
        
        let type: AnchorType
        
        // ARAnchor
        let identifier: String
        let transform: EncodableFloat4x4
        
        // ARPlaneAnchor
        let center: simd_float3
        let extent: simd_float3
        
        init(anchor: ARAnchor) {
            self.type = .anchor
            self.identifier = anchor.identifier.uuidString
            self.transform = EncodableFloat4x4(matrix: anchor.transform)
            //self.center = simd_float3(x: 0.0, y: 0.0, z: 0.0)
            //self.extent = simd_float3(x: 0.0, y: 0.0, z: 0.0)
        }
        
        init(planeAnchor: ARPlaneAnchor) {
            self.type = .planeAnchor
            self.identifier = planeAnchor.identifier.uuidString
            self.transform = EncodableFloat4x4(matrix: planeAnchor.transform)
            //self.center = planeAnchor.center
            //self.extent = planeAnchor.extent
        }
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            self.type = try container.decode(AnchorType.self)
            self.identifier = try container.decode(String.self)
            self.transform = try container.decode(EncodableFloat4x4.self)
            //self.center = try container.decode(simd_float3.self)
            //self.extent = try container.decode(simd_float3.self)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(type)
            try container.encode(identifier)
            try container.encode(transform)
            //try container.encode(center)
            //try container.encode(extent)
        }
    }
    
    
    
    struct EncodableARFrameAnchors: Encodable, Decodable {
        let anchors: [EncodableARAnchor]

        init(from frame: ARFrame) {
            self.anchors = frame.anchors.map { anchor in
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    return EncodableARAnchor(planeAnchor: planeAnchor)
                } else {
                    return EncodableARAnchor(anchor: anchor)
                }
            }
        }
    }

    func encodeARFrameAnchors(arFrame: ARFrame) throws -> Data {
        let encodableARFrameAnchors = EncodableARFrameAnchors(from: arFrame)
        let jsonData = try JSONEncoder().encode(encodableARFrameAnchors)
        return jsonData
    }
    
*/
    
    
    
    
    
    
    // OLD
    
    
    
    
    
    /*
    struct EncodableARAnchor: Encodable {
        
        enum AnchorType: Codable {
            case anchor
            case planeAnchor
        }
        
        let type: AnchorType
        
        // ARAnchor
        let identifier: String
        let transform: EncodableFloat4x4
        
        // ARPlaneAnchor
        let center: simd_float3
        let extent: simd_float3
        
        init(anchor: ARAnchor) {
            self.type = .anchor
            self.identifier = anchor.identifier.uuidString
            self.transform = EncodableFloat4x4(matrix: anchor.transform)
            self.center = simd_float3(x: 0.0, y: 0.0, z: 0.0)
            self.extent = simd_float3(x: 0.0, y: 0.0, z: 0.0)
        }
        
        init(planeAnchor: ARPlaneAnchor) {
            self.type = .planeAnchor
            self.identifier = planeAnchor.identifier.uuidString
            self.transform = EncodableFloat4x4(matrix: planeAnchor.transform)
            self.center = planeAnchor.center
            self.extent = planeAnchor.extent
        }
    }
     */

    
    /*
    
    struct EncodableARPlaneAnchor: Encodable {
        let identifier: String
        let transform: EncodableFloat4x4
        let center: simd_float3
        let extent: simd_float3

        init(from anchor: ARPlaneAnchor) {
            self.identifier = anchor.identifier.uuidString
            self.transform = EncodableFloat4x4(matrix: anchor.transform)
            self.center = anchor.center
            self.extent = anchor.extent
        }
    }

    struct EncodableARFrameAnchors: Encodable {
        let anchors: [EncodableARAnchor]

        init(from frame: ARFrame) {
            self.anchors = frame.anchors.map { anchor in
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    return EncodableARPlaneAnchor(from: planeAnchor)
                } else {
                    return EncodableARAnchor(from: anchor)
                }
            }
        }
    }

    struct EncodableARAnchor: Encodable {
        let identifier: String
        let transform: EncodableFloat4x4

        init(from anchor: ARAnchor) {
            self.identifier = anchor.identifier.uuidString
            self.transform = EncodableFloat4x4(matrix: anchor.transform)
        }
    }

    func encodeARFrameAnchors(arFrame: ARFrame) throws -> Data {
        let encodableARFrameAnchors = EncodableARFrameAnchors(from: arFrame)
        let jsonData = try JSONEncoder().encode(encodableARFrameAnchors)
        return jsonData
    }
     */

    /*
    func encodeSimdFloat4x4(_ matrix: simd_float4x4) -> EncodableFloat4x4 {
        return EncodableFloat4x4(matrix: matrix)
    }
     */

/*
struct SerializedARFrame {
    let capturedImage: Data
    let cameraTransform: simd_float4x4
    //let serializedAnchors: [SerializedAnchor]
}
*/







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
