//
//  DeltaCameraApp.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/29/25.
//

import SwiftUI

import DeltaCore
import GBCDeltaCore

@main
struct DeltaCameraApp: App
{
    init()
    {
        Delta.register(GBC.core)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
