//
//  CaptureExtension.swift
//  CaptureExtension
//
//  Created by Riley Testut on 5/21/25.
//

import Foundation
import LockedCameraCapture
import SwiftUI

@main
struct CaptureExtension: LockedCameraCaptureExtension
{    
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            ContentView(session: session)
        }
    }
}
