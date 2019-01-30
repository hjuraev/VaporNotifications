//
//  FireBaseMessageErrors.swift
//  App
//
//  Created by Halimjon Juraev on 3/25/18.
//

import Foundation

public struct FirebaseMessageResult: Codable {
    let name: String?
    let error: FireBaseResponseError?
    
    var result: Bool {
        if error == nil {
            return true
        }
        return false
    }
    
    init(name: String? = nil, error: FireBaseResponseError = FireBaseResponseError()) {
        self.name = name
        self.error = error
    }
}


struct FireBaseResponseError: Codable {
    let code: Int?
    let message: String?
    let status: String?
    let details: [FireBaseErrorDetails]?
    
    init() {
        self.details = nil
        self.status = nil
        self.code = nil
        self.message = nil
    }
}


struct FireBaseErrorDetails: Codable {
    let errorCode: FirebaseMessageError?
}

public enum FirebaseMessageError: String, Codable {
    case unknownError = "UNSPECIFIED_ERROR"
    case invalidArguments = "INVALID_ARGUMENT"
    case unRegistered = "UNREGISTERED"
    case senderIDMismatch = "SENDER_ID_MISMATCH"
    case quotaExceeded = "QUOTA_EXCEEDED"
    case apnsAuthError = "APNS_AUTH_ERROR"
    case unavailable = "UNAVAILABLE"
    case internalError = "INTERNAL"
}

