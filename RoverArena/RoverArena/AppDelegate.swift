//
//  AppDelegate.swift
//  RoverArena
//
//  Created by Rob Reuss on 2/19/23.
//

import UIKit
import RoverFramework
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        RoverMotors.shared.disconnectRoverMotors()
        SystemState.shared.operationalBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = SystemState.shared.launchBrightness
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        //UIScreen.main.brightness = launchBrightness
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        //UIScreen.main.brightness = operationalBrightness
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        UIScreen.main.brightness = SystemState.shared.operationalBrightness
        SystemState.shared.launchBrightness = UIScreen.main.brightness
    }


}

