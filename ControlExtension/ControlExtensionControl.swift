//
//  ControlExtensionControl.swift
//  ControlExtension
//
//  Created by Riley Testut on 5/21/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct ControlExtensionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rileytestut.Delta-Camera.ControlExtension") {
            ControlWidgetButton(action: DeltaCameraCaptureIntent()) {
                Label("Open Delta Camera", systemImage: "camera")
            }
        }
        .displayName("Delta Camera")
        .description("An example control that runs a timer.")
    }
}
