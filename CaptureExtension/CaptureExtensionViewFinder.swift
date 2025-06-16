//
//  CaptureExtensionViewFinder.swift
//  CaptureExtension
//
//  Created by Riley Testut on 5/21/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import LockedCameraCapture

struct CaptureExtensionViewFinder: UIViewControllerRepresentable
{
    let session: LockedCameraCaptureSession
 
    func makeUIViewController(context: Context) -> UIImagePickerController
    {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.mediaTypes = [UTType.movie.identifier]
        imagePicker.cameraDevice = .rear
        imagePicker.showsCameraControls = false
        imagePicker.videoQuality = .typeHigh
        return imagePicker
    }
 
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context)
    {
    }
}
