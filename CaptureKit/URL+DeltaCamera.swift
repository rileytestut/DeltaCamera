//
//  URL+DeltaCamera.swift
//  Delta Camera
//
//  Created by Riley Testut on 6/16/25.
//

import Foundation

public extension URL
{
    static var gameFileURL: URL {
        let gameFileURL = Self.documentsDirectory.appendingPathComponent("Game.gb")
        return gameFileURL
    }
}
