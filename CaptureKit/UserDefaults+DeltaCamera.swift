//
//  UserDefaults+DeltaCamera.swift
//  CaptureKit
//
//  Created by Riley Testut on 6/3/25.
//

import Foundation
import Roxas

extension UserDefaults
{
    // TODO: Replace this with shared app-container defaults
    static let shared = UserDefaults.standard
    
    @NSManaged
    var exportedPhotoHashes: [String]?
}
