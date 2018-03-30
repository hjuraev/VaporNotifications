//
//  AppleAPNS.swift
//  App
//
//  Created by Halimjon Juraev on 3/15/18.
//

import Vapor

public final class APNSClient: ServiceType {
    
    public static func makeService(for worker: Container) throws -> APNSClient {
        return try APNSClient(worker: worker)
    }
    
    var client: FoundationClient
    var worker: Container
    
    public init(worker: Container) throws{
        self.worker = worker
        self.client = try FoundationClient.makeService(for: worker)
    }
    
    public func send(message: ApplePushMessage) throws -> Future<APNSResult>{
        let response = try client.respond(to: message.getRequest(container: worker))
        return response.map { response -> (APNSResult) in
            debugPrint(response)
            if let data = response.http.body.data {
                debugPrint(String(data: data, encoding: .utf8))
            }
            guard let body = response.http.body.data, body.count != 0 else {
                return APNSResult.success(apnsId: message.messageId, deviceToken: message.deviceToken)
            }
            do {
                let decoder = JSONDecoder()
                let error = try decoder.decode(APNSError.self, from: body)
                return APNSResult.error(apnsId: message.messageId, deviceToken: message.deviceToken, error: error)
            }catch _ {
                return APNSResult.error(apnsId: message.messageId, deviceToken: message.deviceToken, error: APNSError(reason: .Unknown))
            }
        }
    }
    public func sendRaw(message: ApplePushMessage) throws -> Future<Response> {
        return try client.respond(to: message.getRequest(container: worker))
    }
    
}


