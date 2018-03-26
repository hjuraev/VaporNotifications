//
//  FirebaseProvider.swift
//  VaporNotifications
//
//  Created by Halimjon Juraev on 3/26/18.
//

import Foundation
import Vapor

public final class FirebaseProvider: Provider {
    public static var repositoryName = "Firebase"
    
    public func register(_ services: inout Services) throws {
        services.register(Firebase.self)
    }
    
    public func didBoot(_ worker: Container) throws -> EventLoopFuture<Void> {
        return .done(on: worker)
    }
    
}
