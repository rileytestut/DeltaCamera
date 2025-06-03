//
//  DeltaCameraCaptureIntent.swift
//  Delta Camera
//
//  Created by Riley Testut on 5/21/25.
//

import AppIntents

struct DeltaCameraCaptureIntent: CameraCaptureIntent
{
    struct AppContext: Codable
    {
    }
    
    static let title: LocalizedStringResource = "Open Delta Camera"
    static let description = IntentDescription("Capture photos with Delta Camera.")

    @MainActor
    func perform() async throws -> some IntentResult {
//        do {
//            if let context = try await DeltaCameraCaptureIntent.appContext {
//                // Read the camera direction from the appContext.
//                return context.cameraDirection
//            }
//        } catch {
//            // Handle error condition.
//        }
        return .result()
    }
}
