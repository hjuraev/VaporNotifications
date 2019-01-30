//
//  APNSResult.swift
//  App
//
//  Created by Halimjon Juraev on 3/24/18.
//

import Foundation

public enum APNSResult {
    case success(apnsId:String, deviceToken: String)
    case error(apnsId:String, deviceToken: String, error: APNSError)
    case networkError(error: Error)
}
