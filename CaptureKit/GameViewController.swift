//
//  GameViewController.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/30/25.
//

import UIKit

import Roxas
import DeltaCore
import GBCDeltaCore

public class GameViewController: DeltaCore.GameViewController
{
    private let cameraController = CameraController(sessionPreset: .cif352x288, preferredCameraPosition: .back)
    private let cameraProcessor = CameraProcessor()
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.automaticallyPausesWhileInactive = false
        
        Task<Void, Never> {
            await self.cameraController.setDelegate(self)
        }
    }
    
    public override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        Task<Void, Never> {
            do
            {
                try await self.cameraController.startSession()
            }
            catch
            {
                let alertController = UIAlertController(title: String(localized: "Unable to Launch Camera"), message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(.ok)
                self.present(alertController, animated: true)
            }
        }
    }
}

extension GameViewController: CameraControllerDelegate
{
    public func cameraController(_ cameraController: CameraController, didOutputFrame image: CIImage)
    {
        guard let imageData = self.cameraProcessor.process(image) else { return }
        
        GBCEmulatorBridge.shared.cameraFrameData = imageData
    }
}
