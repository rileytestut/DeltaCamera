//
//  DeltaCameraCaptureIntent.swift
//  Delta Camera
//
//  Created by Riley Testut on 5/21/25.
//

import AppIntents

struct DeltaCameraCaptureIntent: CameraCaptureIntent
{
    struct AppContext: Codable, Sendable
    {
    }
    
    static let title: LocalizedStringResource = "Open Delta Camera"
    static let description = IntentDescription("Capture photos with Delta Camera.")

    @MainActor
    func perform() async throws -> some IntentResult
    {
        return .result()
    }
}
