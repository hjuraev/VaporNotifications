//
//  APNSPayload.swift
//  App
//
//  Created by Halimjon Juraev on 3/18/18.
//

import Foundation

public class APNSPayload: Codable {
    
    public var badge: Int?
    
    public var title: String?
    
    public var subtitle: String?
    
    public var body: String?
    
    public var titleLocKey: String?
    
    public var titleLocArgs: [String]?
    
    public var actionLocKey: String?
    
    public var bodyLocKey: String?
    
    public var bodyLocArgs: [String]?
    
    public var aps: String?

    public var launchImage: String?
    
    public var sound: String?
    
    public var category: String?
    
    public var contentAvailable: Bool = false

    public var hasMutableContent: Bool = false
    
    public var threadId: String?

    
    public init() {
        
    }
}

