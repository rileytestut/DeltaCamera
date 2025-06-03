//
//  GameViewController.swift
//  Delta Camera
//
//  Created by Riley Testut on 4/30/25.
//

import UIKit
import AVKit
import Photos
import CryptoKit

import CaptureKit

import Roxas
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
        
        let exportPhotosAction = UIAction(title: NSLocalizedString("Export Photos", comment: ""), image: UIImage(systemName: "square.and.arrow.up.on.square")) { [weak self] _ in
            self?.exportAllPhotos()
        }
        
        let menu = UIMenu(children: [switchCameraAction, exportPhotosAction])
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
            
            processor.cameraController.captureHandler = {
                // Take photo by pressing "A"
                let input = AnyInput(stringValue: GBCGameInput.a.stringValue, intValue: GBCGameInput.a.intValue, type: .controller(.controllerSkin))
                self.controllerView.activate(input)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.controllerView.deactivate(input)
                }
            }
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

private extension CameraViewController
{
    func exportAllPhotos()
    {
        Task<Void, Never> {
            do
            {
                guard let game = self.game else { return }
                
                var exportedPhotoHashes = Set(UserDefaults.shared.exportedPhotoHashes ?? [])
                
                let saveFileURL = game.gameSaveURL
                
                let parser = try RAMParser(fileURL: saveFileURL)
                
                var exportCount = 0
                var errorCount = 0
                var exportError: Error?
                
                for i in 0..<30
                {
                    guard let photo = parser.photo(at: i) else { continue }
                    
                    Logger.main.info("Exporting photo at index \(photo.index) (\([photo.displayIndex]))...")
                    
                    if let image = photo.makeImage()
                    {
                        do
                        {
                            guard let pngData = image.pngData() else { throw CocoaError(.fileReadCorruptFile) }
                            
                            let hash = SHA256.hash(data: pngData)
                            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                            guard !exportedPhotoHashes.contains(hashString) else { continue }
                            
                            try await PHPhotoLibrary.shared().saveImageDataToPhotoLibrary(pngData)
                            
                            exportCount += 1
                            exportedPhotoHashes.insert(hashString)
                        }
                        catch
                        {
                            Logger.main.error("Failed to export photo at index \(i). \(error.localizedDescription, privacy: .public)")
                            errorCount += 1
                            exportError = error
                        }
                    }
                }
                
                if let exportError
                {
                    let title = AttributedString(localized: "Unable to Export ^[\(errorCount) Image](inflect: true)")
                    let alertController = UIAlertController(title: String(title.characters), message: exportError.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(.ok)
                    self.present(alertController, animated: true)
                }
                else
                {
                    let title = AttributedString(localized: "Successfully Exported ^[\(exportCount) Image](inflect: true)")
                    let alertController = UIAlertController(title: String(title.characters), message: String(localized: "You can view them all in your Photo Library."), preferredStyle: .alert)
                    alertController.addAction(.ok)
                    self.present(alertController, animated: true)
                }
                
                UserDefaults.shared.exportedPhotoHashes = Array(exportedPhotoHashes)
            }
            catch
            {
                Logger.main.error("Failed to export photos from save file. \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension CameraViewController: GameViewControllerDelegate
{
    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: any GameController)
    {
        self.menuButton.performPrimaryAction()
    }
}
