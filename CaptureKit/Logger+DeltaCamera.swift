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

//public extension OSLogEntryLog.Level
//{
//    var localizedName: String {
//        switch self
//        {
//        case .undefined: return NSLocalizedString("Undefined", comment: "")
//        case .debug: return NSLocalizedString("Debug", comment: "")
//        case .info: return NSLocalizedString("Info", comment: "")
//        case .notice: return NSLocalizedString("Notice", comment: "")
//        case .error: return NSLocalizedString("Error", comment: "")
//        case .fault: return NSLocalizedString("Fault", comment: "")
//        @unknown default: return NSLocalizedString("Unknown", comment: "")
//        }
//    }
//}
