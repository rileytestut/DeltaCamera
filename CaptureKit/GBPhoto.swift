//
//  GBPhoto.swift
//  Delta Camera
//
//  Created by Riley Testut on 6/3/25.
//  Based on gbcam2png https://github.com/raphnet/gbcam2png
//

import Foundation
import UIKit

struct GBPhoto
{
    let index: Int
    let displayIndex: Int
    
    let photoData: Data
    let thumbnailData: Data
}

extension GBPhoto
{
    func makeImage() -> UIImage?
    {
        // Assumes data is 2bpp tile data, multiple of 16 bytes.
        
        let tilesPerRow = 16
        let palette: [UInt8] = [255, 170, 85, 0] // Black + White
        
        let tileSize = 8
        let bytesPerTile = 16
        let tilesCount = self.photoData.count / bytesPerTile
        let rowsCount = Int(ceil(Double(tilesCount) / Double(tilesPerRow)))
        
        let width = tilesPerRow * tileSize
        let height = rowsCount * tileSize
        var pixels = [UInt8](repeating: 255, count: width * height)
        
        for index in 0 ..< tilesCount
        {
            let offset = index * bytesPerTile
            
            for row in 0 ..< tileSize
            {
                let byte0 = self.photoData[offset + row * 2]
                let byte1 = self.photoData[offset + row * 2 + 1]

                for column in 0 ..< tileSize
                {
                    let mask = UInt8(1 << (7 - column))
                    let lowBit = (byte0 & mask) != 0 ? 1 : 0
                    let highBit = (byte1 & mask) != 0 ? 2 : 0
                    let colorIndex = lowBit | highBit

                    let x = (index % tilesPerRow) * tileSize + column
                    let y = (index / tilesPerRow) * tileSize + row
                    pixels[y * width + x] = palette[colorIndex]
                }
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitsPerComponent = 8
        let bytesPerRow = width
        guard let provider = CGDataProvider(data: Data(bytes: pixels, count: pixels.count) as CFData) else { return nil }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        return image
    }
}
