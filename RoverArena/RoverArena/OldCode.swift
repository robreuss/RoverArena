//
//  OldCode.swift
//  RoverArena
//
//  Created by Rob Reuss on 3/9/23.
//

import Foundation


class bogus {
    
    
    /*
     
     
     /* OLD
     func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
         for anchor in anchors {
             
             if let participantAnchor = anchor as? ARParticipantAnchor {
                 print("Established joint experience with a peer.")
                 AudioServicesPlaySystemSound (1006)
                 // ...
                 /*
                 let anchorEntity = AnchorEntity(anchor: participantAnchor)
                 
                 let coordinateSystem = MeshResource.generateCoordinateSystemAxes()
                 anchorEntity.addChild(coordinateSystem)
                 
                 let color = UIColor.blue
                 let coloredSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.03),
                                                 materials: [SimpleMaterial(color: color, isMetallic: true)])
                 anchorEntity.addChild(coloredSphere)
                 
                 arView.scene.addAnchor(anchorEntity)
                 */
             } else if anchor.name == "Anchor for object placement" {
                 print("Got an anchor for object placement")
                 
                 if Common.getHostDevice() == .iPhone14ProMax {
                     if arenaFloorEntity == nil {
                         buildArenaOnAnchor(anchor)
                     }
                 }
                 
                 return
                 
                 //AudioServicesPlaySystemSound (1005)
                 // Create a cube at the location of the anchor.
                 let boxLength: Float = 0.05
                 // Color the cube based on the user that placed it.
                 let color = UIColor.blue
                 let coloredCube = ModelEntity(mesh: MeshResource.generateBox(size: boxLength),
                                               materials: [SimpleMaterial(color: color, isMetallic: true)])
                 // Offset the cube by half its length to align its bottom with the real-world surface.
                 coloredCube.position = [0, boxLength / 2, 0]
                 
                 // Attach the cube to the ARAnchor via an AnchorEntity.
                 //   World origin -> ARAnchor -> AnchorEntity -> ModelEntity
                 let anchorEntity = RealityKit.AnchorEntity(anchor: anchor)
                 anchorEntity.addChild(coloredCube)
                 arView.scene.addAnchor(anchorEntity)
             }
             print("Anchor name: \(anchor.name), id \(anchor.identifier)")
         }
     }
     */
     
     
     */

        
    
    
    /*
    // Add pan gesture recognizer
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    panGesture.delegate = self
    arView.addGestureRecognizer(panGesture)
    */
        /*
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            
            guard let planeEntity = arenaFloorEntity else { return }
            
            // Rotate the box entity based on pan gesture translation
            let translation = sender.translation(in: arView)
            let rotationAngle = simd_float3(x: Float(translation.y), y: Float(-translation.x), z: 0) * .pi / 180
            //planeEntity.transform.rotation *= simd_quatf(angle: rotationAngle.x, axis: [1, 0, 0])
            planeEntity.transform.rotation *= simd_quatf(angle: rotationAngle.y, axis: [0, 1, 0])
            
            // Reset the gesture translation to avoid cumulative rotation
            sender.setTranslation(.zero, in: arView)
        }
        */
        
        /*
         
         
         @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: arView)
        
        switch Common.getHostDevice() {
            
        case .iPadPro12:
            print("Placing object is response to tap.")
            // Attempt to find a 3D location on a horizontal surface underneath the user's touch location.
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                // Add an ARAnchor at the touch location with a special name you check later in `session(_:didAdd:)`.
                let anchor = ARAnchor(name: "Anchor for object placement", transform: firstResult.worldTransform)
                arView.session.add(anchor: anchor)
                
            } else {
                // messageLabel.displayMessage("Can't place object - no surface found.\nLook for flat surfaces.", duration: 2.0)
                print("Warning: Object placement failed.")
            }
            
        case .iPhoneXSMax:
            print("Placing object is response to tap.")
            // Attempt to find a 3D location on a horizontal surface underneath the user's touch location.
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                // Add an ARAnchor at the touch location with a special name you check later in `session(_:didAdd:)`.
                let anchor = ARAnchor(name: "Anchor for object placement", transform: firstResult.worldTransform)
                arView.session.add(anchor: anchor)
                
            } else {
                // messageLabel.displayMessage("Can't place object - no surface found.\nLook for flat surfaces.", duration: 2.0)
                print("Warning: Object placement failed.")
            }
            
        case .iPhone14ProMax:
            print("Placing object is response to tap.")
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            //buildArenaOnAnchor(location)
            /*
            // Attempt to find a 3D location on a horizontal surface underneath the user's touch location.
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                // Add an ARAnchor at the touch location with a special name you check later in `session(_:didAdd:)`.
                let anchor = ARAnchor(name: "Anchor for object placement", transform: firstResult.worldTransform)
                arView.session.add(anchor: anchor)
                
            } else {
                // messageLabel.displayMessage("Can't place object - no surface found.\nLook for flat surfaces.", duration: 2.0)
                print("Warning: Object placement failed.")
            }
            */
        default:
            print("No device")
        }

        
    }

         */
    
    
        
        //let magnitude: Float = Float(sqrt(pow(deltaY, 2) + pow(deltaX, 2)))
        
        
        // TEST
        /*
        let currentPosition = self.currentDevicePoint
        let targetPosition = desinationPoint
        let vector = CGPoint(x: targetPosition.x - currentPosition.x, y: targetPosition.y - currentPosition.y)
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(self.arView.cameraTransform.rotation.angle))
        let rotatedVector = vector.applying(rotationTransform)
        
        let deltaX2 = rotatedVector.x - self.currentDevicePoint.x
        let deltaY2 = rotatedVector.y - self.currentDevicePoint.y
        
        angleInRadians = atan2(deltaY2, deltaX2)
        */
        
        
        //angleInRadians = atan2(rotatedVector.x, rotatedVector.y)
        
        
        
    /*
   // arView.automaticallyConfigureSession = false

    configuration = ARWorldTrackingConfiguration()
    configuration?.environmentTexturing = .automatic
    configuration?.planeDetection = [.horizontal]
    configuration?.isAutoFocusEnabled = true
    configuration?.isCollaborationEnabled = true
    arView.session.run(configuration!)
    
    sessionIDObservation = observe(\.arView.session.identifier, options: [.new], changeHandler: { object, change in

        print("SessionID changed to: \(change.newValue!)")
        self.sendARSessionIDToPeers()
        
    })
     
     */
     
    
    //arView.debugOptions = [.showStatistics, .showAnchorOrigins, .showPhysics, .showAnchorGeometry, .showSceneUnderstanding]
    //arView.debugOptions = [.showSceneUnderstanding]

    //arView.debugOptions = [ .showPhysics]
    
    //ARView.DebugOptions.showSceneUnderstanding
    
    
    
    // BUTTONS
    
    /*
    func buttonPress(button: RoverGameController.GameControllerButton) {
        
        switch button {
        case .b:
            //RoverMotors.shared.goForwardMeters(2.0.feetToMeters, speed: 0.7, direction: .forward)
            channels.sendCommandType(type: .beginTransitToPoint, floatValue: 0.3, pointValue: CGPoint(x: 0.0, y: 0.1), toDevice: .iPhone14ProMax)
        case .x:
            channels.sendCommandType(type: .buildArena, floatValue: 0.0, pointValue: CGPointZero, toDevice: .iPhone14ProMax)
            //RoverMotors.shared.goForwardMeters(2.0.feetToMeters, speed: 0.7, direction: .backward)
        case .y:
            channels.sendCommandType(type: .cancelTransitToPoint, floatValue: 0.0, pointValue: CGPoint(x: 0.0, y: 0.0), toDevice: .iPhone14ProMax)
        case .a:
            self.view.sendSubviewToBack(imageView)
            self.view.bringSubviewToFront(arView)
        default:
            print("Unhandled gc button: \(button)")
        }
    }
    */
    
    
    
    // OLD
    /*
    func receivedCollaborationData(_ data: Data, from sourceDevice: SourceDevice) {
        
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
            print("\(Common.getHostDevice()) is updating collaboration from: \(sourceDevice.rawValue)")
            arView.session.update(with: collaborationData)
            return
        }
        // ...
        let sessionIDCommandString = "SessionID:"
        if let commandString = String(data: data, encoding: .utf8), commandString.starts(with: sessionIDCommandString) {
            let newSessionID = String(commandString[commandString.index(commandString.startIndex,
                                                                     offsetBy: sessionIDCommandString.count)...])
            // If this peer was using a different session ID before, remove all its associated anchors.
            // This will remove the old participant anchor and its geometry from the scene.
            if let oldSessionID = peerSessionIDs[sourceDevice] {
                removeAllAnchorsOriginatingFromARSessionWithID(oldSessionID)
            }
            print("Received new peer session ID: \(newSessionID)")
            peerSessionIDs[sourceDevice] = newSessionID
        }
    }
    */
}
