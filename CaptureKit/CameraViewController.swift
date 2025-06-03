//
//  GameViewController.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/30/25.
//

import UIKit
import AVKit

import DeltaCore
import GBCDeltaCore

class CameraViewController: GameViewController
{
    weak var cameraFeedProcessor: CameraFeedProcessor?
    
    private var menuButton: UIButton!
    
    private var captureInteraction: AVCaptureEventInteraction?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.delegate = self
        
        self.menuButton = UIButton(type: .custom)
        self.menuButton.isUserInteractionEnabled = false
        self.controllerView.addSubview(self.menuButton)
        
        let switchCameraAction = UIAction(title: NSLocalizedString("Switch Camera", comment: ""), image: UIImage(systemName: "camera.rotate")) { [weak self] _ in
            self?.cameraFeedProcessor?.cameraController.switchCameras()
        }
        
        let menu = UIMenu(children: [switchCameraAction])
        self.menuButton.menu = menu
        self.menuButton.showsMenuAsPrimaryAction = true
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if self.captureInteraction == nil, let processor = self.cameraFeedProcessor
        {
            let interaction = processor.cameraController.makeCaptureInteraction()
            self.view.addInteraction(interaction)
            self.captureInteraction = interaction
        }
    }
    
    override func viewDidLayoutSubviews()
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

extension CameraViewController: GameViewControllerDelegate
{
    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: any GameController)
    {
        self.menuButton.performPrimaryAction()
    }
}
