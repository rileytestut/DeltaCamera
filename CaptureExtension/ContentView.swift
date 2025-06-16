//
//  ContentView.swift
//  Delta Camera
//
//  Created by Riley Testut on 6/16/25.
//

import Foundation
import SwiftUI
import LockedCameraCapture

struct ContentView: View
{
    let session: LockedCameraCaptureSession
    
    @State
    private var error: Error?
    
    @State
    private var isShowingErrorAlert: Bool = false
    
    var body: some View {
        CaptureExtensionViewFinder(session: session)
            .overlay {
                VStack(spacing: 15) {
                    Text("Lock Screen capture not yet supported.")
                    Button("Open Delta Camera", action: openApp)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .tint(Color.purple)
            }
            .alert("Unable to Open App", isPresented: $isShowingErrorAlert, presenting: error) { error in
                Button("OK") {}
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

private extension ContentView
{
    func openApp()
    {
        Task<Void, Never> { @MainActor in
            do
            {                
                let activity = NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
                try await self.session.openApplication(for: activity)
            }
            catch
            {
                self.error = error
                self.isShowingErrorAlert = true
            }
        }
    }
}
