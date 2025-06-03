//
//  CameraController.swift
//  Prime
//
//  Created by Riley Testut on 5/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation
import AVKit

import CaptureKit

@available(iOS 18.0, *)
public actor CameraController: NSObject
{
    /// State
    public private(set) var running = false
    
    /// AVFoundation
    public let captureSession: AVCaptureSession
    
    /// Cameras
    public var currentCamera: AVCaptureDevice?
    {
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
    
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        return self.sessionQueue.asUnownedSerialExecutor()
    }
    
    public private(set) var isPrepared: Bool = false
    
    public private(set) var controls: [AVCaptureControl] = []
    
    internal private(set) var isCameraControlActive: Bool = false
    
    private var _isPressingCameraControl: Bool = false
    
    /// Private
    public let sessionQueue = DispatchQueue(label: "com.rileytestut.Prime.CameraController.sessionQueue") as! _DispatchSerialExecutorQueue
    
    public init(sessionPreset: AVCaptureSession.Preset, preferredCameraPosition: AVCaptureDevice.Position = .unspecified)
    {
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = sessionPreset
        
        super.init()
        
        self.sessionQueue.async {
            self.assumeIsolated { cameraController in
                cameraController.captureSession.beginConfiguration()
                cameraController.addCameraDevice(for: preferredCameraPosition)
                cameraController.captureSession.commitConfiguration()
            }
        }
    }
}

/// Session
@available(iOS 18.0, *)
public extension CameraController
{
    func prepareSession()
    {
        self.captureSession.beginConfiguration()
        defer {
            self.captureSession.commitConfiguration()
        }
        
        guard self.captureSession.supportsControls else {
            Logger.main.error("Capture session does not support Camera Control.")
            return
        }
        
        self.captureSession.setControlsDelegate(self, queue: self.sessionQueue)
        
        for control in self.controls
        {
            self.captureSession.addControl(control)
        }
        
        self.isPrepared = true
    }
    
    func startSession()
    {
        guard !self.running else { return }
        self.running = true
        
        if !self.isPrepared
        {
            self.prepareSession()
        }
        
        self.captureSession.startRunning()
    }
    
    func stopSession()
    {
        guard self.running else { return }
        self.running = false
        
        self.captureSession.stopRunning()
    }
    
    func switchCameras()
    {
        guard let videoInput = self.captureSession.inputs.first(where: { $0.ports.first?.mediaType == .video }), let currentPosition = videoInput.ports.first?.sourceDevicePosition else { return }
        
        self.captureSession.beginConfiguration()
        self.captureSession.removeInput(videoInput)
        
        let position: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
        let device = self.addCameraDevice(for: position)
        
        self.captureSession.commitConfiguration()
    }
    
    func addCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice?
    {
        let captureDevice: AVCaptureDevice?
        
        switch position
        {
        case .front, .back: captureDevice = self.cameraDevice(forPosition: position)
        case .unspecified: captureDevice = AVCaptureDevice.default(for: .video)
        }
        
        if let captureDevice = captureDevice
        {
            // Configure capture device to record at 60fps
            do
            {
                try captureDevice.lockForConfiguration()
                
                if let activeFormat = captureDevice.formats.first(where: { $0.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate == 60 }) })
                {
                    captureDevice.activeFormat = activeFormat
                    captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
                    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
                }
                
                captureDevice.unlockForConfiguration()
            }
            catch let error as NSError
            {
                print(error)
            }
            
            self.add(captureDevice)
        }
        
        return captureDevice
    }
}

/// Capture Controls
@available(iOS 18.0, *)
public extension CameraController
{
    func setControls(_ controls: [AVCaptureControl])
    {
        self.controls = controls
    }
    
    func makeCaptureInteraction() -> AVCaptureEventInteraction
    {
        let interaction = AVCaptureEventInteraction { [weak self] event in
            guard let self else { return }
            
            if event.phase == .began && self.isCameraControlActive
            {
                self._isPressingCameraControl = true
            }
            
            if self._isPressingCameraControl
            {
                // Camera Control
                
//                switch event.phase
//                {
//                case .began: self.activate(Input.cameraControl)
//                case .ended, .cancelled: self.deactivate(Input.cameraControl)
//                    
//                @unknown default: break
//                }
                
                switch event.phase
                {
                case .began: Logger.main.info("Activating camera control input.")
                case .ended, .cancelled: Logger.main.info("Deactivating camera control input.")
                @unknown default: break
                }
                
                
            }
            else
            {
                // Volume Down
                
//                switch event.phase
//                {
//                case .began: self.activate(Input.volumeDown)
//                case .ended, .cancelled:
//                    Task { @MainActor in
//                        // Delay deactivation because activation is also delayed.
//                        try await Task.sleep(for: .milliseconds(32))
//                        self.deactivate(Input.volumeDown)
//                    }
//                @unknown default: break
//                }
                
                switch event.phase
                {
                case .began: Logger.main.info("Activating volume down input.")
                case .ended, .cancelled: Logger.main.info("Deactivating volume down input.")
                @unknown default: break
                }
            }
            
            if event.phase == .ended && self._isPressingCameraControl
            {
                self._isPressingCameraControl = false
            }
            
        } secondary: { event in
            // Volume Up
            
//            switch event.phase
//            {
//            case .began: self.activate(Input.volumeUp)
//            case .ended, .cancelled:
//                Task { @MainActor in
//                    // Delay deactivation because activation is also delayed.
//                    try await Task.sleep(for: .milliseconds(32))
//                    self.deactivate(Input.volumeUp)
//                }
//                
//            @unknown default: break
//            }
            
            switch event.phase
            {
            case .began: Logger.main.info("Activating volume up input.")
            case .ended, .cancelled: Logger.main.info("Deactivating volume up input.")
            @unknown default: break
            }
        }
        
        return interaction
    }

}

@available(iOS 18.0, *)
extension CameraController: AVCaptureSessionControlsDelegate
{
    // Dynamically isolated to actor because we assigned delegate's queue to actor's queue.
    
    public nonisolated func sessionControlsDidBecomeInactive(_ session: AVCaptureSession)
    {
        Logger.main.debug("Session controls became inactive.")
        
        self.assumeIsolated { controller in
            controller.isCameraControlActive = false
        }
    }
    
    public nonisolated func sessionControlsDidBecomeActive(_ session: AVCaptureSession)
    {
        Logger.main.debug("Session controls became active.")
        
        self.assumeIsolated { controller in
            controller.isCameraControlActive = true
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

/// Capture Devices
@available(iOS 18.0, *)
public extension CameraController
{
    func cameraDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice?
    {
        return self.captureDevice(withMediaType: .video, position: position)
    }
    
    private func captureDevice(withMediaType mediaType: AVMediaType, position: AVCaptureDevice.Position) -> AVCaptureDevice?
    {
        let devices = (AVCaptureDevice.devices(for: mediaType) as! [AVCaptureDevice]).filter({ $0.position == position })
        return devices.first
    }
}

@available(iOS 18.0, *)
private extension CameraController
{
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

        }
        catch let error as NSError
        {
            print(error)
        }
        
        return false
    }
}
