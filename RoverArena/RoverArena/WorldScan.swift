//
//  WorldCapture.swift
//  ARRover
//
//  Created by Rob Reuss on 7/15/22.
//

import Foundation
import RoverFramework
import ElementalController
import CoreLocation
import ARKit

public protocol WorldScanDelegate: AnyObject {
    func worldScanComplete()
}

class WorldScan: NSObject, CLLocationManagerDelegate {

    public static let shared = WorldScan()
    
    public var delegate: WorldScanDelegate?
    
    static private let rotationQueue = DispatchQueue(label: "net.simplyformed.rotation",
                                                 qos: .background)

    var locationManager = CLLocationManager()

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        //heading = newHeading.magneticHeading
        //print("Heading: \(heading)")
    }

    let roverMotors = RoverMotors.shared

    //var heading: Double = 0.0
    var currentAbsoluteHeading: Double {
        get {
            return locationManager.heading?.magneticHeading ?? 0.0
        }
    }
    
    var rotateIncrement: Double = 10.0
    var stepStartTime = Date()
    
    var standardSpeed: Float = 0.4

    /*
    override init() {
        super.init()

    }
    */
    func setup() {
        locationManager.delegate = self
        locationManager.startUpdatingHeading()

    }
    
    func startWorldTracking() {
        
        print("Starting world tracking")

        // 0 is fully tilted forward, 180 is fully tilted backwards
        // 0 is panned to the left, 180 is fully to the right
        // 100 is correctly tilted down

        WorldScan.rotationQueue.async {
            //self.captureDegrees(360, speed: self.standardSpeed, rotateIncrement: 180.0)
            self.captureScene360()
        }
        
        print("heading: \(currentAbsoluteHeading)")
        sleep(1)
        
    }

    
    
    func normalizedHeading(_ startHeading: Double) -> Double {
        if currentAbsoluteHeading < startHeading + 0.01 {
            return 360 + currentAbsoluteHeading
        } else {
            return currentAbsoluteHeading
        }
    }

    
    func captureScene360() {
        
        print("initial raw heading: \(currentAbsoluteHeading)")

        //var rotationCount: Double = 0.0
        //var targetHeading = 0.0

        //let steps: [Double] = stride(from: rotateIncrement, to: degreesToRotate, by: rotateIncrement).map{$0}
        let direction = 1.0
        
        //print("Steps \(steps)")
        if !RoverMotors.shared.connectedToRoverMotors {
            logError("Cannot capture because rover motors are not connected")
            return
        }

        //let normalizedStartHeading = normalizedHeading(startHeading: startHeading)
        
        var startHeading = currentAbsoluteHeading
        let rotationTarget: Double = 360.0

        var virtualHeading: Double {
            get {
                var vh = currentAbsoluteHeading - startHeading
                if vh < 0 { vh = vh + 360 }
                return vh // Brings down to starting point of zero
            }
        }
        
        var virtualTarget: Double {
            get {
                return virtualHeading + rotationTarget
            }
        }
        
        let accuracy = 1.5
        var rotationCount = 1.0
        let timeout = 25.0
       // let targetHeading = normalizedHeading(startHeading) + 360

        var remainingDegrees: Double {
            get {
                return rotationTarget - virtualHeading
            }
        }

        var adjustedSpeed: Float {
            get {
                switch remainingDegrees {
                case 0...45:
                    return 0.18
                case 45...357:
                    return 0.6
                case 357...360:
                    return 0.3
                default:
                    return 0.2
                }
                
            }
        }
        
        let startRotationTime = Date()
        standardSpeed = 0.2
        //print("Remaining degrees: \(remainingDegrees)")
        while remainingDegrees - accuracy > 0 && abs(startRotationTime.timeIntervalSince(Date())) < timeout {
            
            roverMotors.rotate(speed: adjustedSpeed * Float(direction))
                usleep(25000)
               // print("    start heading: \(startHeading), virtual heading: \(virtualHeading), virtual target: \(rotationTarget), speed: \(adjustedSpeed)")
        }
        //print("     Elapsed time: \(abs(startRotationTime.timeIntervalSince(Date()))), heading: \(normalizedHeading(startHeading)), target: \(targetHeading)")

        //startHeading = heading
        roverMotors.brake()
        
        rotationCount += 1

        usleep(500000)
        
        guard let delegate = delegate else { return }
        (DispatchQueue.main).sync {  delegate.worldScanComplete() } // Back to main thread

    }
        
        
/*
        for step in steps {
            
            let targetHeading = startHeading + step
            let startRotationTime = Date()
            print("")
            print("\(rotationCount) heading: \(normalizedHeading(startHeading: startHeading)), target: \(targetHeading)")
            while normalizedHeading(startHeading: startHeading) <= targetHeading && abs(startRotationTime.timeIntervalSince(Date())) < 5 {
                roverMotors.rotate(speed: speed * Float(direction))
                usleep(10000)
                print("    heading: \(normalizedHeading(startHeading: startHeading)), target: \(targetHeading)")
            }
            print("     Elapsed time: \(abs(startRotationTime.timeIntervalSince(Date()))), heading: \(normalizedHeading(startHeading: startHeading)), target: \(targetHeading)")

            startHeading = heading
            roverMotors.brake()
            
            // rotationCount += 1
  
            usleep(500000)
            
        }
        */

        
        /*
        

        func normalizedTargetHeading() -> Double {
            return normalizedStartingHeading + (rotationCount * rotateIncrement)
        }
        

        
        func offset() -> Double {
            return abs(normalizedTargetHeading() - normalizedCurrentHeading())
        }

        var rotationStartTime = Date()
        let rotationTimeLimit = 3.0
        let degreePrecision = 5.0
        let direction = 1.0
        
        print("heading: \(heading) normalized: \(normalizedCurrentHeading())")
        let maxRotations = (degreesToRotate / rotateIncrement)
        print("maxRotations: \(maxRotations)")
        while normalizedCurrentHeading() >= 0 && rotationCount <= maxRotations  {
            
            print("rotation count: \(rotationCount)")

            while normalizedTargetHeading() > normalizedCurrentHeading() && rotationCount <= maxRotations && normalizedCurrentHeading() < 359 {
                
                print("Target: \(normalizedTargetHeading() ), Current: \(normalizedCurrentHeading())")
                print("rotation count: \(rotationCount), maxRotations: \(maxRotations)")
                //print("offset: \(offset())")

                roverMotors.rotate(speed: speed * Float(direction))
                
                usleep(10000)
                
                //print("heading: \(heading)")
                
                //print("offset: \(offset()), normalizedCurrentHeading(): \(normalizedCurrentHeading()), normalizedTargetHeading: \(normalizedTargetHeading())")
                
            }
            
            print("Breaking")
            roverMotors.brake()
            
            rotationCount += 1
  
            usleep(500000)
            
            //print("normalizedCurrentHeading: \(normalizedCurrentHeading()), degreesToRotate: \(degreesToRotate)")
        }
        */

    
    
    
    func captureDegrees(_ degreesToRotate: Double, speed: Float, rotateIncrement: Double) {
        
        print("initial raw heading: \(currentAbsoluteHeading)")

        //var rotationCount: Double = 0.0
        //var targetHeading = 0.0

        //let steps: [Double] = stride(from: rotateIncrement, to: degreesToRotate, by: rotateIncrement).map{$0}
        let direction = 1.0
        
        //print("Steps \(steps)")
        if !RoverMotors.shared.connectedToRoverMotors {
            logError("Cannot capture because rover motors are not connected")
            return
        }

        //let normalizedStartHeading = normalizedHeading(startHeading: startHeading)
        
        let accuracy = 5.0
        var rotationCount = 1.0
        let timeout = 10.0
        let requiredRotations = Int(degreesToRotate / rotateIncrement)
        print("Required rotations: \(requiredRotations)")
        var startHeading = currentAbsoluteHeading
        for step in 0...requiredRotations {
            let targetHeading = normalizedHeading(startHeading) + rotateIncrement
            let startRotationTime = Date()
            print("")
            print("\(rotationCount) heading: \(normalizedHeading(startHeading)), target: \(targetHeading)")
            while normalizedHeading(startHeading) <= (targetHeading - accuracy) && abs(startRotationTime.timeIntervalSince(Date())) < timeout {
                roverMotors.rotate(speed: speed * Float(direction))
                usleep(10000)
                // print("    heading: \(normalizedHeading(startHeading)), target: \(targetHeading)")
            }
            print("     Elapsed time: \(abs(startRotationTime.timeIntervalSince(Date()))), heading: \(normalizedHeading(startHeading)), target: \(targetHeading)")

            startHeading = currentAbsoluteHeading
            roverMotors.brake()
            
            rotationCount += 1
  
            usleep(500000)
        }
        
    }

        
    
}


