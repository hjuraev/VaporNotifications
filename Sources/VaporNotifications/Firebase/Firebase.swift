//
//  Firebase.swift
//  App
//
//  Created by Halimjon Juraev on 3/24/18.
//

import Foundation
import Vapor

class Firebase: Service {
    
    var client: FoundationClient
    var worker: Container
    
    init(worker: Container) throws{
        self.worker = worker
        self.client = try FoundationClient.makeService(for: worker)
    }
    
    func send<T: Codable>(message: FirebaseMessage<T>, profile: FirebaseProfile) throws -> Future<FirebaseMessageResult>{
        let request = try profile.getRequest(message: message, container: worker)
        let response = try client.respond(to: request)
        
        return response.map(to: FirebaseMessageResult.self, { response -> (FirebaseMessageResult) in
            switch response.http.status {
            case .badRequest:
                return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .invalidJson, message_id: nil, canonical_ids: nil)])
            case .unauthorized:
                return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .authenticationError, message_id: nil, canonical_ids: nil)])
            case .requestTimeout:
                return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .requestTimeout, message_id: nil, canonical_ids: nil)])
            case .serviceUnavailable:
                return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .internalServerError, message_id: nil, canonical_ids: nil)])
            case .internalServerError:
                return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .internalServerError, message_id: nil, canonical_ids: nil)])
            case .custom(code: 200, reasonPhrase: ""), .ok:
                guard let body = response.http.body.data else {
                    return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .internalServerError, message_id: nil, canonical_ids: nil)])
                }
                let decoder = JSONDecoder()
                let result = try decoder.decode(FirebaseMessageResult.self, from: body)
                return result
            default:
                return FirebaseMessageResult(multicast_id: 0, success: 0, failure: 1, canonical_ids: 0, results: [Result(error: .internalServerError, message_id: nil, canonical_ids: nil)])
            }
        })
    }
    
    
}
