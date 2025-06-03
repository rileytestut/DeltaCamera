//
//  GBPhoto.swift
//  Delta Camera
//
//  Created by Riley Testut on 6/3/25.
//  Based on gbcam2png https://github.com/raphnet/gbcam2png
//

import Foundation
import UIKit

private let initialPhotoOffset = 0x2000
private let photoSize = 0x1000

struct RAMHeader
{
    var scratchpad1: Data // 0x11FC, 0000 - 11fb
    var gameface: Data // 0xE00, 11fc - 1ffb
    var scratchpad2: Data // 4
}

struct RAMParser
{
    let fileURL: URL
    
    private let data: Data
    
    private let header: RAMHeader
    
    init(fileURL: URL) throws
    {
        self.fileURL = fileURL
        self.data = try Data(contentsOf: fileURL)
        
        let scratchpad1Size = 0x11FC
        let gamefaceSize = 0xE00
        let scratchpad2Size = 4
        
        let scratchpad1 = Data(self.data[0 ..< scratchpad1Size])
        let gameface = Data(self.data[scratchpad1Size ..< (scratchpad1Size + gamefaceSize)])
        let scratchpad2 = Data(self.data[(scratchpad1Size + gamefaceSize) ..< (scratchpad1Size + gamefaceSize + scratchpad2Size)])
        
        self.header = RAMHeader(scratchpad1: scratchpad1, gameface: gameface, scratchpad2: scratchpad2)
    }
    
    func photo(at index: Int) -> GBPhoto?
    {
        guard let displayIndex = self.displayIndex(forIndex: index) else { return nil }
        
        let offset = self.offset(forPhotoAtIndex: index)
        
        let largePhotoSize = 0xE00
        let smallPhotoSize = 0x100
        
        let largePhotoBuffer = Data(self.data[offset ..< (offset + largePhotoSize)])
        let smallPhotoBuffer = Data(self.data[(offset + largePhotoSize) ..< (offset + largePhotoSize + smallPhotoSize)])
        
        let photo = GBPhoto(index: index, displayIndex: displayIndex, photoData: largePhotoBuffer, thumbnailData: smallPhotoBuffer)
        return photo
    }
}

private extension RAMParser
{
    func offset(forPhotoAtIndex index: Int) -> Int
    {
        let offset = initialPhotoOffset + index * photoSize
        return offset
    }
    
    func displayIndex(forIndex index: Int) -> Int?
    {
        guard index < 30 else { return nil }
        
        let displayIndex = self.header.scratchpad1[0x11B2 + index]
        if (displayIndex == 0xFF)
        {
            return nil // Deleted
        }
        
        return Int(displayIndex)
    }
}

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
        let image = self.decodeGameBoyTiles(self.photoData, tilesPerRow: 16)
        return image
    }
}

private extension GBPhoto
{
    /// Decodes an array of Game Boy tiles (2bpp format) into a UIImage.
    /// - Parameters:
    ///   - data: Raw 2bpp tile data (multiple of 16 bytes).
    ///   - tilesPerRow: Number of tiles per row in the final image.
    ///   - palette: Optional array of 4 grayscale colors (defaults to black→white).
    func decodeGameBoyTiles(_ data: Data, tilesPerRow: Int, palette: [UInt8] = [255, 170, 85, 0]) -> UIImage? {
        let tileSize = 8
        let bytesPerTile = 16
        let numTiles = data.count / bytesPerTile
        let numRows = Int(ceil(Double(numTiles) / Double(tilesPerRow)))

        let width = tilesPerRow * tileSize
        let height = numRows * tileSize
        var pixels = [UInt8](repeating: 255, count: width * height)

        for tileIndex in 0..<numTiles {
            let tileOffset = tileIndex * bytesPerTile
            for row in 0..<tileSize {
                let b0 = data[tileOffset + row * 2]
                let b1 = data[tileOffset + row * 2 + 1]

                for col in 0..<tileSize {
                    let mask = UInt8(1 << (7 - col))
                    let lowBit = (b0 & mask) != 0 ? 1 : 0
                    let highBit = (b1 & mask) != 0 ? 2 : 0
                    let colorIndex = lowBit | highBit

                    let x = (tileIndex % tilesPerRow) * tileSize + col
                    let y = (tileIndex / tilesPerRow) * tileSize + row
                    pixels[y * width + x] = palette[colorIndex]
                }
            }
        }

        return imageFromGrayscalePixels(pixels: pixels, width: width, height: height)
    }

    /// Converts a grayscale pixel buffer to a UIImage.
    func imageFromGrayscalePixels(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitsPerComponent = 8
        let bytesPerRow = width
        guard let provider = CGDataProvider(data: NSData(bytes: pixels, length: pixels.count)) else {
            return nil
        }

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

        return UIImage(cgImage: cgImage)
    }
}
