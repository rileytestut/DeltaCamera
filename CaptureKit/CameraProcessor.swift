//
//  CameraProcessor.swift
//  Delta Camera
//
//  Created by Riley Testut on 6/4/25.
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

class CameraProcessor
{
    private let ciContext = CIContext()
    
    func process(_ image: CIImage) -> Data?
    {
        // Crop 128x112 image from the center
        let size = CGSize(width: 128, height: 112)
        let cropRect = AVMakeRect(aspectRatio: size, insideRect: image.extent)
        let croppedImage = image.cropped(to: cropRect)
        
        let scaleX = size.width / croppedImage.extent.width
        let scaleY = size.height / croppedImage.extent.height
        let scale = min(scaleX, scaleY)
        
        let scaledImage = croppedImage.transformed(by: .identity.scaledBy(x: scale, y: scale).translatedBy(x: -croppedImage.extent.minX, y: -croppedImage.extent.minY))
        
        let grayscaleFilter = CIFilter.colorControls()
        grayscaleFilter.inputImage = scaledImage
        grayscaleFilter.saturation = 0.0
        
        guard let outputImage = grayscaleFilter.outputImage else { return nil }
        
        // Create 1-byte per pixel grayscale context
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * Int(size.width)
        
        var pixelData = Data(count: bytesPerRow * Int(size.height))
        pixelData.withUnsafeMutableBytes { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            self.ciContext.render(outputImage, toBitmap: baseAddress, rowBytes: bytesPerRow, bounds: scaledImage.extent, format: .L8, colorSpace: grayColorSpace)
        }
        
        // Gambatte expects image data in 32-bit format, despite only reading lowest byte for grayscale value.
        let uint32PixelData = Data(bytes: pixelData.map { UInt32($0) }, count: pixelData.count * MemoryLayout<UInt32>.size)
        return uint32PixelData
    }
}
