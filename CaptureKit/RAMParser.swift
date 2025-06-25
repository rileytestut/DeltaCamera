//
//  SaveFileParser.swift
//  CaptureKit
//
//  Created by Riley Testut on 6/17/25.
//  Based on gbcam2png https://github.com/raphnet/gbcam2png
//

import Foundation

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
