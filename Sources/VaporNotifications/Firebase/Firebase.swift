//
//  Firebase.swift
//  App
//
//  Created by Halimjon Juraev on 11/6/18.
//

import Foundation
import FCM
import Crypto
import JWT
import Vapor


public class Firebase {
    let email: String
    let key: String
    let projectId: String
    
    let scope = "https://www.googleapis.com/auth/cloud-platform"
    let audience = "https://www.googleapis.com/oauth2/v4/token"
    let actionsBaseURL = "https://fcm.googleapis.com/v1/projects/"
    
    let gAuthPayload: GAuthPayload
    var _jwt: String = ""
    var accessToken: String?
    
    // MARK: Default configurations
    
    public var apnsDefaultConfig: FCMApnsConfig<FCMApnsPayload>?
    public var androidDefaultConfig: FCMAndroidConfig?
    public var webpushDefaultConfig: FCMWebpushConfig?
    
    // MARK: Initialization
    /// Key should be PEM Private key

    init(email: String, key: String, projectId: String) {
        self.email = email
        self.projectId = projectId
        self.key = key
        gAuthPayload = GAuthPayload(iss: email, sub: email, scope: scope, aud: audience)
        do {
            _jwt = try generateJWT()
        } catch {
            fatalError("FCM Unable to generate JWT: \(error)")
        }
    }
    
    
    func generateJWT() throws -> String {
        gAuthPayload.update()
        let pk = try RSAKey.private(pem: key)
        let signer = JWTSigner.rs256(key: pk)
        let jwt = JWT<GAuthPayload>(payload: gAuthPayload)
        let jwtData = try jwt.sign(using: signer)
        return String(data: jwtData, encoding: .utf8)!
    }
    
    func getJWT() throws -> String {
        if !gAuthPayload.hasExpired {
            return _jwt
        }
        _jwt = try generateJWT()
        return _jwt
    }
    
    
    public func sendMessage(_ client: Client, message: FCMMessage) throws -> Future<FirebaseMessageResult> {

        if message.android == nil,
            let androidDefaultConfig = androidDefaultConfig {
            message.android = androidDefaultConfig
        }
        if message.webpush == nil,
            let webpushDefaultConfig = webpushDefaultConfig {
            message.webpush = webpushDefaultConfig
        }
        let url = actionsBaseURL + projectId + "/messages:send"
        return try getAccessToken(client).flatMap { accessToken in

            var headers = HTTPHeaders()
            headers.add(name: "Authorization", value: "Bearer "+accessToken)
            headers.add(name: "Content-Type", value: "application/json")
            return client.post(url, headers: headers) { req throws in

                struct Payload: Codable {
                    var validate_only: Bool
                    var message: FCMMessage
                }
                let payload = Payload(validate_only: false, message: message)
                try req.content.encode(payload, as: .json)
                let data = try JSONEncoder().encode(payload)
                print(JSON(data))
                }.map { response in
                    guard let data = response.http.body.data else {
                        return FirebaseMessageResult()
                    }
                    let decoder = JSONDecoder()
                    return try decoder.decode(FirebaseMessageResult.self, from: data)
                }.catch({ error in
                    debugPrint(error)
                })
        }
    }
    
    
    func getAccessToken(_ client: Client) throws -> Future<String> {
        if !gAuthPayload.hasExpired, let token = accessToken {
            return client.container.eventLoop.newSucceededFuture(result: token)
        }
        var payload: [String: String] = [:]
        payload["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        payload["assertion"] = try getJWT()

        return client.post(audience) { req throws in

            try req.content.encode(payload, as: .urlEncodedForm)
            }.map { res in
                
                struct Result: Codable {
                    var access_token: String
                }
                guard let data = res.http.body.data else {
                    throw Abort(.notFound, reason: "Data not found")
                }
                if res.http.status.code != 200 {
                    let code = "Code: \(res.http.status.code)"
                    let message = "Message: \(String(data: data, encoding: .utf8) ?? "n/a")"
                    let reason = "[FCM] Unable to refresh access token. \(code) \(message)"
                    throw Abort(.internalServerError, reason: reason)
                }
                let result = try JSONDecoder().decode(Result.self, from: data)
                return result.access_token
            }.catch({ error in
                debugPrint(error)
            })
    }
    
    
    
}
