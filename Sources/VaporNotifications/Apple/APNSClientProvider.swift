//
//  APNSClientProvider.swift
//  VaporNotifications
//
//  Created by Halimjon Juraev on 3/26/18.
//

import Foundation
import Vapor

public final class APNSClientProvider: Provider {
    public static var repositoryName = "APNS"
    
    public func register(_ services: inout Services) throws {
        services.register(APNSClient.self)
    }
    
    public func didBoot(_ worker: Container) throws -> EventLoopFuture<Void> {
        return .done(on: worker)
    }
    
}
