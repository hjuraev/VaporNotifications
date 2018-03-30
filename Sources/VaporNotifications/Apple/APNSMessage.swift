//
//  APNSMessage.swift
//  App
//
//  Created by Halimjon Juraev on 3/18/18.
//

import Foundation
import Vapor
import Bits
import JWT


public struct ApplePushMessage {
    
    public let profile: APNSProfile
    
    public let messageId: String = UUID().uuidString
    public let deviceToken: String
    
    public var collapseIdentifier: String?
    
    public var threadIdentifier: String?
    
    public var expirationDate: Date?

    public let priority: Priority

    public enum Priority: Int {
        case energyEfficient = 5
        case immediately = 10
    }
    
    /// APNS Payload
    public let payload: APNSPayload
    
    /// Use sandbox server URL or not
    public let dev:Bool
    
    private func getHeaders() -> HTTPHeaders{
        var headers: HTTPHeaders = HTTPHeaders()
        
        headers.add(name: HTTPHeaderName("apns-id"), value: messageId)
        if expirationDate != nil {
            headers.add(name: HTTPHeaderName("apns-expiration"), value: String(expirationDate?.timeIntervalSince1970.rounded() ?? 0.0))
        }
        headers.add(name: HTTPHeaderName("apns-priority"), value: "\(priority.rawValue)")
        headers.add(name: HTTPHeaderName("apns-topic"), value: profile.topic)
        headers.add(name: .connection, value: "Keep-Alive")

        if let collapseId = collapseIdentifier {
            headers.add(name: HTTPHeaderName("apns-collapse-id"), value: collapseId)
        }
        if let threadId = threadIdentifier {
            headers.add(name: HTTPHeaderName("thread-id"), value: threadId)
        }
        if profile.tokenExpiration <= Date() {
            try? profile.generateToken()
        }
        
        headers.add(name: HTTPHeaderName("authorization"), value: "bearer \(profile.Token ?? "")")
        return headers
    }
    
    func getRequest(container: Container) -> Request {
        let request = Request(using: container)
        for header in getHeaders() {
            request.http.headers.add(name: header.name, value: header.value)
        }
        request.http.method = .POST
        request.http.url = hostURL(token: deviceToken)
        
        let body = HTTPBody(string: payload.body!)
        request.http.body = body

        return request
    }
    
    public init(priority: Priority = .immediately, dev: Bool = false, deviceToken: String, profile: APNSProfile, payload: APNSPayload) {
        self.priority = priority
        self.dev = dev
        self.payload = payload
        self.profile = profile
        self.deviceToken = deviceToken
    }
    
    
    public func hostURL(token:String) -> URL {
        if dev {
            let url = URL(string: "https://api.development.push.apple.com/3/device/\(deviceToken)")
            return url!
        } else {
            let url = URL(string: "https://api.push.apple.com/3/device/\(deviceToken)")
            return url!
        }
    }

}



struct APNSJWTPayload: JWTPayload {
    let iss: String
    let iat = IssuedAtClaim(value: Date())
    let exp = ExpirationClaim(value: Date(timeInterval: 3500, since: Date()))
    func verify() throws {
    }
}





