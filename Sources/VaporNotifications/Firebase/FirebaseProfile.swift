//
//  FirebaseProfile.swift
//  App
//
//  Created by Halimjon Juraev on 3/24/18.
//

import Foundation
import Vapor
import JWT
import Crypto
import JWT
import CNIOOpenSSL
import Bits
import NIO
import Vapor

public struct FirebaseProfile {

    var serverKey: String
    
    public init(serverKey: String) throws {
        self.serverKey = serverKey
    }
    
    public func getRequest<T: Codable>(message: FirebaseMessage<T>, container: Container) throws -> Request {
        let request = Request(using: container)
        for header in getHeaders() {
            request.http.headers.add(name: header.name, value: header.value)
        }
        request.http.method = .POST
        request.http.url = hostURL()
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        request.http.body = HTTPBody(data: data)
        return request
    }
    
    public struct GoogleJWTPayload: JWTPayload {
        let aud: String?
        let iss: String?
        let sub: String?
        let uid: String = UUID().uuidString
        let iat:Int = Int(Date().timeIntervalSince1970.rounded())
        let exp:Int = Int(Date().timeIntervalSince1970.rounded() + 360)
        
        public func verify() throws {
        }
    }
    
    public func hostURL() -> URL {
        let url = URL(string: "https://fcm.googleapis.com/fcm/send")
        return url!
    }
    
    private func getHeaders() -> HTTPHeaders {
        var headers: HTTPHeaders = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        headers.add(name: .accept, value: "application/json")
        headers.add(name: .authorization, value: "key=\(serverKey)")
        return headers
    }
    
    public struct JWTGoogleHeader: Codable {
        /// The algorithm used with the signing
        public var alg: String?
        
        /// The Signature's Content Type
        public var typ: String?
        
        /// The Payload's Content Type
        public var cty: String?
        
        /// Critical fields
        public var crit: [String]?
        
        /// The JWT key identifier
        public var kid: String?
        
        /// Create a new JWT header
        public init(
            alg: String? = nil,
            typ: String? = "JWT",
            cty: String? = nil,
            crit: [String]? = nil,
            kid: String? = nil
            ) {
            self.alg = alg
            self.typ = typ
            self.cty = cty
            self.crit = crit
            self.kid = kid
        }
    }
}

