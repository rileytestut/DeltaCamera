//
//  Logger+DeltaCamera.swift
//  CaptureKit
//
//  Created by Riley Testut on 6/3/25.
//

@_exported import OSLog

public extension Logger
{
    static let deltaCameraSubsystem = "com.rileytestut.DeltaCamera"
    
    static let main = Logger(subsystem: deltaCameraSubsystem, category: "Main")
}
