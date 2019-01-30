//
//  APNSProfile.swift
//  App
//
//  Created by Halimjon Juraev on 3/20/18.
//

import Foundation
import JWT
import Vapor

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
    
    public var debugLogging: Bool = false

    public var description: String {
        return """
        Topic \(topic)
        \nPort \(port.rawValue)
        \nTeamID \(teamId)
        \nKeyID \(keyId)
        \nToken \(Token ?? "")
        \nTOK - Key ID: \(String(describing: keyId))
        """
    }
    init(teamId: String, topic: String, keyId: String, publicKey: String, privateKey: String, container: Container) throws {
        self.teamId = teamId
        self.topic = topic
        self.keyId = keyId
        let (priv, pub) = try KeyUtilities.generateKeys(Path: privateKey, container: container)
        self.publicKey = pub
        self.privateKey = priv
        try generateToken()
    }

    
    func generateToken() throws {
        
        let JWTheaders = JWTHeader(alg: "ES256", cty: nil, crit: nil, kid: keyId)
        let payload = APNSJWTPayload(iss: teamId)
        
        let signer = JWTSigner.es256(key: privateKey)
        
        let jwt = JWT(header: JWTheaders, payload: payload)
        
        let signed = try jwt.sign(using: signer)
        let stringToken = String(bytes: signed, encoding: .utf8)
        guard let token = stringToken else {
            throw TokenError.tokenWasNotGeneratedCorrectly
        }
        tokenExpiration = Date(timeInterval: 3500, since: Date())
        self.Token = token
    }

}
