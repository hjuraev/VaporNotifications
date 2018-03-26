//
//  FireBaseMessageErrors.swift
//  App
//
//  Created by Halimjon Juraev on 3/25/18.
//

import Foundation

public struct FirebaseMessageResult: Codable {
    public let multicast_id: Int
    public let success: Int
    public let failure: Int
    public let canonical_ids: Int
    public let results: [Result]
    public var result: MessageResult {
        get {
            print(success)
            if success == 1 {
                return .SUCCESS
            } else {
                return .FAILED
            }
        }
    }
    
    public enum MessageResult {
        case SUCCESS
        case FAILED
    }
}

public struct Result: Codable {
    public let error: FirebaseMessageError?
    public let message_id: String?
    public let canonical_ids: String?
}
public enum FirebaseMessageError: String, Codable {
    case missingRegistration = "MissingRegistration"
    case invalidRegistration = "InvalidRegistration"
    case notRegistered = "NotRegistered"
    case invalidPackageName = "InvalidPackageName"
    case authenticationError = "authenticationError"
    case mismatchSenderId = "MismatchSenderId"
    case invalidJson = "invalidJson"
    case invalidParameters = "invalidParameters"
    case messageToBig = "MessageTooBig"
    case invalidDataKey = "InvalidDataKey"
    case invalidTtl = "InvalidTtl"
    case unavailable = "Unavailable"
    case internalServerError = "InternalServerError"
    case requestTimeout = "requestTimeout"
    case deviceMessageRateExceeded = "DeviceMessageRateExceeded"
    case topicMessageRateExceeded = "TopicsMessageRateExceeded"
    case invalidApnsCredential = "InvalidApnsCredential"
}

