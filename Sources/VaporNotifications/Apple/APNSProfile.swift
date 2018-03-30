//
//  APNSProfile.swift
//  App
//
//  Created by Halimjon Juraev on 3/20/18.
//

import Foundation
import JWT

public class APNSProfile {
    public enum Port: Int {
        case p443 = 443, p2197 = 2197
    }

    public var topic: String
    public var port: Port = .p443
    public var teamId: String
    public var keyId: String
    public var Token: String?
    public var tokenExpiration: Date = Date()
    var privateKey: Data
    var publicKey: Data
    
    public var keyPath: String
    public var debugLogging: Bool = false

    public var description: String {
        return """
        Topic \(topic)
        \nPort \(port.rawValue)
        \nCER - Key path: \(keyPath)
        \nTOK - Key ID: \(String(describing: keyId))
        """
    }
    
    
    public init(topic: String, teamId: String, keyId: String, keyPath: String, debugLogging: Bool = false, dev: Bool = false) throws {
        
        self.teamId = teamId
        self.topic = topic
        self.keyId = keyId
        self.debugLogging = debugLogging
        self.keyPath = keyPath
        
        //// GENERATING TOKEN
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: keyPath) else {
            throw InitializeError.keyFileDoesNotExist
        }
        
        let (priv, pub) = KeyUtilities.generateKeys(Path: keyPath)
        self.publicKey = pub
        self.privateKey = priv
        try generateToken()
    }
    
    func generateToken() throws {
        let JWTheaders = JWTHeader(alg: "ES256", cty: nil, crit: nil, kid: keyId)
        let payload = APNSJWTPayload(iss: teamId)
        
        let signer = JWTSigner.es256(key: privateKey)
        
        var jwt = JWT(header: JWTheaders, payload: payload)
        
        let signed = try jwt.sign(using: signer)
        let stringToken = String(bytes: signed, encoding: .utf8)
        guard let token = stringToken else {
            throw TokenError.tokenWasNotGeneratedCorrectly
        }
        tokenExpiration = Date(timeInterval: 3500, since: Date())
        self.Token = token
    }

}
