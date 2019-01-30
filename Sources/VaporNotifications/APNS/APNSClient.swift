//
//  AppleAPNS.swift
//  App
//
//  Created by Halimjon Juraev on 3/15/18.
//

import Vapor

public final class APNSClient: Service{
    
    
    var devHost = "api.development.push.apple.com"
    var prodHost = "api.push.apple.com"
    
    public func send(message: ApplePushMessage, request: Request) throws -> Future<APNSResult>{
        
        var host: String
        if message.dev {
            host = devHost
        } else {
            host = prodHost
        }
        
        return HTTP2Clientv1.connect(scheme: .https, hostname: host, port: 443, on: request) { error in
            let logger = try? request.make(Logger.self)
            logger?.error(error.localizedDescription)
            debugPrint(error)
            }.flatMap { client -> Future<APNSResult> in
                return try self.sendMessage(client: client, message: message)
        }
    }
    
    
    private func sendMessage(client: HTTP2Clientv1, message: ApplePushMessage)throws -> Future<APNSResult> {
        
        return client.send(message.getRequest()).map({ response -> APNSResult in
            _ = client.close()
            guard let body = response.body.data, body.count != 0 else {
                return APNSResult.success(apnsId: message.messageId, deviceToken: message.deviceToken)
            }
            do {
                let decoder = JSONDecoder()
                let error = try decoder.decode(APNSError.self, from: body)
                return APNSResult.error(apnsId: message.messageId, deviceToken: message.deviceToken, error: error)
            }catch _ {
                return APNSResult.error(apnsId: message.messageId, deviceToken: message.deviceToken, error: APNSError(reason: .Unknown))
            }
            
        }).catch({ (error) in
            debugPrint(error)
        })
    }
    
    
}


