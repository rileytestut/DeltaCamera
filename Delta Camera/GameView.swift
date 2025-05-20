//
//  GameView.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/30/25.
//

import SwiftUI

import DeltaCore
import GBCDeltaCore

struct GameView: View
{
    let game: Game
    
    private let cameraFeedProcessor = CameraFeedProcessor()
    
    var body: some View {
        WrappedGameView(game: game, cameraFeedProcessor: cameraFeedProcessor)
            .onAppear {
                self.cameraFeedProcessor.videoDataHandler = { imageData in
                    GBCEmulatorBridge.shared.cameraData = imageData
                }
                self.cameraFeedProcessor.start()
            }
//            .onReceive(self.cameraFeedProcessor.videoDataPublisher.receive(on: RunLoop.main)) { imageData in
//                imageData.withUnsafeBytes { baseAddress in
//                    let uiImage = imageFromARGB32Bitmap(baseAddress.baseAddress?.assumingMemoryBound(to: UInt32.self), 128, 112)
//                    _ = uiImage
//                }
//                
//                GBCEmulatorBridge.shared.cameraData = imageData
//            }
    }
}

private struct WrappedGameView: UIViewControllerRepresentable
{
    let game: Game
    let cameraFeedProcessor: CameraFeedProcessor
    
    func makeUIViewController(context: Context) -> some UIViewController
    {
        let gameViewController = CameraViewController()
        gameViewController.game = self.game
        gameViewController.loadViewIfNeeded()
        gameViewController.controllerView.playerIndex = 0
        gameViewController.cameraFeedProcessor = self.cameraFeedProcessor
        return gameViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context)
    {
    }
}
//
//#Preview {
//    GameView()
//}
