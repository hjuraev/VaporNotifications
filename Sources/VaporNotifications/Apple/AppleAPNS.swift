//
//  AppleAPNS.swift
//  App
//
//  Created by Halimjon Juraev on 3/15/18.
//

import Vapor

class APNSClient: Service {
    var client: FoundationClient
    var worker: Container
    
    init(worker: Container) throws{
        self.worker = worker
        self.client = try FoundationClient.makeService(for: worker)
    }
    
    func send(message: ApplePushMessage) throws -> Future<APNSResult>{
        let response = try client.respond(to: message.getRequest(container: worker))
        return response.map { response -> (APNSResult) in
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
}


