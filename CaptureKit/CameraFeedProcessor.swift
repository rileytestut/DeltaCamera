//
//  CameraFeedProcessor.swift
//  GBCDeltaCore
//
//  Created by Riley Testut on 4/30/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import Combine

@available(iOS 18, *)
public class CameraFeedProcessor: NSObject
{
    public var videoDataPublisher: some Publisher<Data, Never> {
        return self.videoDataSubject
    }
    private let videoDataSubject = PassthroughSubject<Data, Never>()
    
    public var videoDataHandler: ((Data) -> Void)?
    
    public let cameraController: CameraController
    private let videoDataOutput: AVCaptureVideoDataOutput
    
    private let context = CIContext()
    private var observations = Set<NSKeyValueObservation>()
    
    public init(preferredCameraPosition: AVCaptureDevice.Position = .unspecified)
    {
        self.cameraController = CameraController(sessionPreset: .cif352x288, preferredCameraPosition: preferredCameraPosition)
        
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        super.init()
        
        self.videoDataOutput.setSampleBufferDelegate(self, queue: self.cameraController.sessionQueue)
        
        self.cameraController.sessionQueue.async {
            self.cameraController.assumeIsolated { cameraController in
                cameraController.captureSession.addOutput(self.videoDataOutput)
            }
        }
        
        Task {
            await self.updateCameraControls()
        }
    }
    
    public func start()
    {
        Task {
            await self.cameraController.startSession()
        }
    }
}

@available(iOS 18, *)
extension CameraFeedProcessor
{
    func updateCameraControls() async
    {
        // Remove previous KVO observations.
        self.observations = []
        
//        guard let emulatorCore else {
//            // Remove all controls.
//            await self.cameraController.setControls([])
//            return
//        }
        
        guard let input = self.cameraController.captureSession.inputs.first(where: { $0.ports.first?.mediaType == .video }) as? AVCaptureDeviceInput else { return }


        // Create a control to adjust the device's video zoom factor.
        let systemZoomSlider = AVCaptureSystemZoomSlider(device: input.device) { zoomFactor in
            // Calculate and display a zoom value.
            let displayZoom = input.device.displayVideoZoomFactorMultiplier * zoomFactor
            Logger.main.info("Current zoom level: \(displayZoom)")
        }

        // Create a control to adjust the device's exposure bias.
        let systemBiasSlider = AVCaptureSystemExposureBiasSlider(device: input.device) { exposureTargetBias in
            Logger.main.info("Current exposure: \(exposureTargetBias)")
        }
        
//        let fastForwardControl = AVCaptureSlider(String(localized: "Fast Forward"), symbolName: "forward.fill", in: 0.5...8)
//        fastForwardControl.prominentValues = [0.5, 1.0, 2.0, 4.0, 8.0]
//        fastForwardControl.setActionQueue(DispatchQueue.main) { [weak self] speed in
//            guard let self else { return }
//            
//            if speed == 1.0
//            {
//                // Equivalent to deactivating fast forward.
//                Logger.main.info("Setting FF speed to 1.0...")
//            }
//            else
//            {
//                Logger.main.info("Setting FF speed to \(speed)...")
//            }
//        }
//        
//        let filtersControl = AVCaptureIndexPicker(String(localized: "Filters"), symbolName: "camera.filters", localizedIndexTitles: ["None", "CRT", "VHS"])
//        filtersControl.setActionQueue(DispatchQueue.main) { [weak self] index in
//            Logger.main.info("Setting filter to filter at index: \(index)")
//        }
        
//        let fastForwardObservation = emulatorCore.observe(\.rate, options: [.initial, .new]) { [weak self, weak fastForwardControl] (core, change) in
//            guard let self, let fastForwardControl, let newValue = change.newValue else { return }
//            DispatchQueue.main.async { // Must be set on same queue as provided action queue
//                fastForwardControl.value = Float(newValue)
//            }
//        }
//        self.observations.insert(fastForwardObservation)
        
        await self.cameraController.setControls([systemZoomSlider, systemBiasSlider])
    }
}

@available(iOS 18, *)
extension CameraFeedProcessor: AVCaptureVideoDataOutputSampleBufferDelegate
{
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Extract the image from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Rotate image to correct orientation
        let rotatedImage = ciImage.oriented(.right)
        
        // Crop 128x112 image from the center
        let size = CGSize(width: 128, height: 112)
        let cropRect = AVMakeRect(aspectRatio: size, insideRect: rotatedImage.extent)
        let croppedImage = rotatedImage.cropped(to: cropRect)
        
        let scaleX = size.width / croppedImage.extent.width
        let scaleY = size.height / croppedImage.extent.height
        let scale = min(scaleX, scaleY)
        
        //let cropRect = CGRect(x: (rotatedImage.extent.width / 2) - size.width/2, y: (rotatedImage.extent.height / 2) - size.height/2, width: size.width, height: size.height)
        //let croppedImage = rotatedImage.cropped(to: cropRect)
        
        let outputImage = croppedImage.transformed(by: .identity.scaledBy(x: scale, y: scale).translatedBy(x: -croppedImage.extent.minX, y: -croppedImage.extent.minY))
        
        // Render to pixel buffer
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &outputBuffer)
        guard status == noErr, let outputBuffer = outputBuffer else { return }
        
        self.context.render(outputImage, to: outputBuffer)
        
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        
        if let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer)?.assumingMemoryBound(to: UInt32.self)
        {
            let imageData = Data(bytes: baseAddress, count: Int(size.width) * Int(size.height) * 4)
//            self.videoDataSubject.send(imageData)
            self.videoDataHandler?(imageData)
        }
        
        CVPixelBufferUnlockBaseAddress(outputBuffer, [])
    }
}
