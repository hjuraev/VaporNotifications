//
//  FirebaseMessage.swift
//  App
//
//  Created by Halimjon Juraev on 3/24/18.
//

import Foundation

public struct FirebaseMessage<T: Codable>: Codable{

    public var to: String
    public var collapse_key: String?
    public var priority: Priority
    public var time_to_live: Date?
    public var data: T
    
    public var Payload: FirebaseMessagePayload?

    public enum Priority: String, Codable {
        case high = "high"
        case normal = "normal"
    }
}

public struct FirebaseMessagePayload: Codable {
    
    public var badge: Int?

    public var title: String?

    public var body: String?

    public var icon: String?

    public var tag: String?

    public var color: String?
    
    public var sound: String?

}
