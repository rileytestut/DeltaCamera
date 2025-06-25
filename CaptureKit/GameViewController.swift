//
//  GameViewController.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/30/25.
//

import UIKit
import AVKit

import Roxas
import DeltaCore
import GBCDeltaCore

public class GameViewController: DeltaCore.GameViewController
{
    private let cameraController = CameraController(sessionPreset: .cif352x288, preferredCameraPosition: .back)
    private let cameraProcessor = CameraProcessor()
    
    private var menuButton: UIButton!
    private var captureInteraction: AVCaptureEventInteraction!
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.delegate = self
        self.automaticallyPausesWhileInactive = false
        
        self.menuButton = UIButton(type: .custom)
        self.menuButton.isUserInteractionEnabled = false
        self.controllerView.addSubview(self.menuButton)
        
        let switchCameraAction = UIAction(title: NSLocalizedString("Switch Camera", comment: ""), image: UIImage(systemName: "camera.rotate")) { [weak self] _ in
            self?.switchCameras()
        }
        
        let menu = UIMenu(children: [switchCameraAction])
        self.menuButton.menu = menu
        self.menuButton.showsMenuAsPrimaryAction = true
        
        self.captureInteraction = self.cameraController.makeCaptureInteraction { [weak self] in
            self?.pressAButton()
        }
        self.view.addInteraction(self.captureInteraction)
        
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
    
    public override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        guard let traits = self.controllerView.controllerSkinTraits,
              let controllerSkin = self.controllerView.controllerSkin,
              let items = controllerSkin.items(for: traits),
              let menuItem = items.first(where: { $0.inputs.allInputs.contains(where: { $0.stringValue == StandardGameControllerInput.menu.rawValue }) })
        else { return }
        
        // Show menu at menu item location
        var frame = menuItem.extendedFrame
        frame.origin.x *= self.controllerView.bounds.width
        frame.origin.y *= self.controllerView.bounds.height
        frame.size.width *= self.controllerView.bounds.width
        frame.size.height *= self.controllerView.bounds.height
        
        self.menuButton.frame = frame
    }
}

private extension GameViewController
{
    func switchCameras()
    {
        Task<Void, Never> {
            guard let activeCamera = await self.cameraController.activeCamera else { return }
            
            let position: AVCaptureDevice.Position = (activeCamera.position == .back) ? .front : .back
            guard let camera = await self.cameraController.defaultCamera(for: position) else { return }
            
            await self.cameraController.setActiveCamera(camera)
        }
    }
    
    func pressAButton()
    {
        let input = AnyInput(stringValue: GBCGameInput.a.stringValue, intValue: GBCGameInput.a.intValue, type: .controller(.controllerSkin))
        self.controllerView.activate(input)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.controllerView.deactivate(input)
        }
    }
}

extension GameViewController: GameViewControllerDelegate
{
    public func gameViewController(_ gameViewController: DeltaCore.GameViewController, handleMenuInputFrom gameController: any GameController)
    {
        self.menuButton.performPrimaryAction()
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
