//
//  PHPhotoLibrary+DeltaCamera.swift
//  Delta
//
//  Created by Riley Testut on 4/24/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit
import Photos
import UniformTypeIdentifiers

extension PHPhotoLibrary
{
    func saveImageDataToPhotoLibrary(_ pngData: Data) async throws
    {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    return continuation.resume(throwing: PHPhotosError(.accessUserDenied))
                }
                
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.png.identifier
                
                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: pngData, options: options)
                } completionHandler: { success, error in
                    if let error
                    {
                        continuation.resume(throwing: error)
                    }
                    else
                    {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
