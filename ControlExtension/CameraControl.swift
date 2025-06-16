//
//  CameraControl.swift
//  ControlExtension
//
//  Created by Riley Testut on 5/21/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct CameraControl: ControlWidget
{
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rileytestut.DeltaCamera.CameraControl") {
            ControlWidgetButton(action: DeltaCameraCaptureIntent()) {
                Label("Open Delta Camera", systemImage: "camera")
            }
        }
        .displayName("Delta Camera")
        .description("Take a photo with Delta Camera.")
    }
}
