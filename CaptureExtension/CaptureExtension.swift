//
//  CaptureExtension.swift
//  CaptureExtension
//
//  Created by Riley Testut on 5/21/25.
//

import Foundation
import LockedCameraCapture
import SwiftUI

import DeltaCore
import GBCDeltaCore

@main
struct CaptureExtension: LockedCameraCaptureExtension
{    
    init()
    {
        Delta.register(GBC.core)
    }
    
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            CaptureExtensionViewFinder(session: session)
        }
    }
}
