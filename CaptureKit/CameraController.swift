//
//  CameraController.swift
//  Prime
//
//  Created by Riley Testut on 5/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import AVKit

public protocol CameraControllerDelegate: AnyObject
{
    func cameraController(_ cameraController: CameraController, didOutputFrame image: CIImage)
}

public actor CameraController: NSObject
{
    private(set) weak var delegate: CameraControllerDelegate?
    
    /// State
    public private(set) var isRunning = false
    
    /// AVFoundation
    public let captureSession: AVCaptureSession
        
    /// Actor
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        return self.sessionQueue.asUnownedSerialExecutor()
    }
    
    /// Private
    private let sessionQueue = DispatchQueue(label: "com.rileytestut.Prime.CameraController.sessionQueue") as! _DispatchSerialExecutorQueue
    private let videoDataOutput: AVCaptureVideoDataOutput
    
    private let preferredInitialCameraPosition: AVCaptureDevice.Position
    
    private var isPrepared: Bool = false
    private var isCameraControlActive: Bool = false
    
    public init(sessionPreset: AVCaptureSession.Preset, preferredCameraPosition: AVCaptureDevice.Position = .unspecified)
    {
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = sessionPreset
        
        self.preferredInitialCameraPosition = preferredCameraPosition
        
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        super.init()
        
        self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
    }
}

public extension CameraController
{
    func setDelegate(_ delegate: CameraControllerDelegate)
    {
        self.delegate = delegate
    }
    
    func startSession() throws
    {
        guard !self.isRunning else { return }
        
        if !self.isPrepared
        {
            try self.prepareSession()
        }
        
        self.captureSession.startRunning()
        self.isRunning = true
    }
    
    func stopSession()
    {
        guard self.isRunning else { return }
        
        self.captureSession.stopRunning()
        self.isRunning = false
    }
}

/// Cameras
public extension CameraController
{
    var activeCamera: AVCaptureDevice? {
        guard let inputs = self.captureSession.inputs as? [AVCaptureDeviceInput] else { return nil }
        
        for input in inputs
        {
            if input.ports.first?.mediaType == .video
            {
                return input.device
            }
        }
        
        return nil
    }
    
    func defaultCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice?
    {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera], mediaType: .video, position: position)
        
        let device = session.devices.first
        return device
    }
    
    func setActiveCamera(_ captureDevice: AVCaptureDevice)
    {
        self.captureSession.beginConfiguration()
        
        if let videoInput = self.captureSession.inputs.first(where: { $0.ports.first?.mediaType == .video })
        {
            // Remove previous active camera input.
            self.captureSession.removeInput(videoInput)
        }
        
        self.add(captureDevice)
        
        self.captureSession.commitConfiguration()
    }
}

/// Camera Control
public extension CameraController
{
    @MainActor
    func makeCaptureInteraction(_ captureHandler: @escaping () -> Void) -> AVCaptureEventInteraction
    {
        let interaction = AVCaptureEventInteraction { event in
            switch event.phase
            {
            case .began:
                Logger.main.info("Activating capture button input.")
                captureHandler()
                
            case .ended, .cancelled: Logger.main.info("Deactivating capture button input.")
            @unknown default: break
            }
        }
        
        return interaction
    }
}

private extension CameraController
{
    func prepareSession() throws
    {
        guard !self.isPrepared else { return }
        
        self.captureSession.beginConfiguration()
        
        guard let captureDevice = self.defaultCamera(for: self.preferredInitialCameraPosition) ?? AVCaptureDevice.default(for: .video) else { throw AVError(.deviceNotConnected) }
        self.add(captureDevice)
        
        self.captureSession.addOutput(self.videoDataOutput)
        
        if self.captureSession.supportsControls
        {
            self.captureSession.setControlsDelegate(self, queue: self.sessionQueue)
            
            let controls = self.makeDefaultControls(for: captureDevice)
            for control in controls
            {
                self.captureSession.addControl(control)
            }
        }
        else
        {
            Logger.main.info("Capture session does not support Camera Control.")
        }
        
        self.captureSession.commitConfiguration()
        
        self.isPrepared = true
    }
    
    func makeDefaultControls(for device: AVCaptureDevice) -> [AVCaptureControl]
    {
        let position = device.position
        
        let zoomSlider = AVCaptureSystemZoomSlider(device: device) { zoomFactor in
            Logger.main.info("Updating \(String(describing: position), privacy: .public) camera zoom level: \(zoomFactor)")
        }

        let exposureSlider = AVCaptureSystemExposureBiasSlider(device: device) { exposureTargetBias in
            Logger.main.info("Updating \(String(describing: position), privacy: .public) camera exposure: \(exposureTargetBias)")
        }
        
        return [zoomSlider, exposureSlider]
    }
    
    @discardableResult
    func add(_ captureDevice: AVCaptureDevice) -> Bool
    {
        do
        {
            let videoDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            if self.captureSession.canAddInput(videoDeviceInput)
            {
                self.captureSession.addInput(videoDeviceInput)
                return true
            }
            else
            {
                throw AVError(.unsupportedDeviceActiveFormat) //TODO: Throw more specific error
            }
        }
        catch
        {
            Logger.main.error("AVCaptureSession doesn't support device \(captureDevice, privacy: .public). \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate
{
    public nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Rotate image to correct orientation
        let rotatedImage = ciImage.oriented(.right)
        
        self.assumeIsolated { cameraController in
            cameraController.delegate?.cameraController(self, didOutputFrame: rotatedImage)
        }
    }
}

extension CameraController: AVCaptureSessionControlsDelegate
{
    // Dynamically isolated to actor because we assigned delegate's queue to actor's queue.
    
    public nonisolated func sessionControlsDidBecomeActive(_ session: AVCaptureSession)
    {
        Logger.main.debug("[CameraController] Session controls became active.")
        
        self.assumeIsolated { controller in
            controller.isCameraControlActive = true
        }
    }
    
    public nonisolated func sessionControlsDidBecomeInactive(_ session: AVCaptureSession)
    {
        Logger.main.debug("[CameraController] Session controls became inactive.")
        
        self.assumeIsolated { controller in
            controller.isCameraControlActive = false
        }
    }
    
    public nonisolated func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession)
    {
        Logger.main.debug("Session controls entered fullscreen appearance.")
    }
    
    public nonisolated func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession)
    {
        Logger.main.debug("Session controls exited fullscreen appearance.")
    }
}
