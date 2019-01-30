//
//  HTTP2Response.swift
//  App
//
//  Created by Halimjon Juraev on 5/26/18.
//

import Foundation
import HTTP


public struct HTTPResponse: HTTPMessage {
    /// Internal storage is an NIO `HTTPResponseHead`
    public var head: HTTPResponseHead
    
    // MARK: Properties
    
    /// The HTTP version that corresponds to this response.
    public var version: HTTPVersion {
        get { return head.version }
        set { head.version = newValue }
    }
    
    /// The HTTP response status.
    public var status: HTTPResponseStatus {
        get { return head.status }
        set { head.status = newValue }
    }
    
    /// The header fields for this HTTP response.
    /// The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically
    /// when the `body` property is mutated.
    public var headers: HTTPHeaders {
        get { return head.headers }
        set { head.headers = newValue }
    }
    
    /// The `HTTPBody`. Updating this property will also update the associated transport headers.
    ///
    ///     httpRes.body = HTTPBody(string: "Hello, world!")
    ///
    /// Also be sure to set this message's `contentType` property to a `MediaType` that correctly
    /// represents the `HTTPBody`.
    public var body: HTTPBody {
        didSet { updateTransportHeaders() }
    }
    
    /// If set, reference to the NIO `Channel` this response came from.
    public var channel: Channel?
    
    /// Get and set `HTTPCookies` for this `HTTPResponse`
    /// This accesses the `"Set-Cookie"` header.
    public var cookies: HTTPCookies {
        get { return HTTPCookies.parse(setCookieHeaders: headers[.setCookie]) ?? [:] }
        set { newValue.serialize(into: &self) }
    }
    
    /// See `CustomStringConvertible`
    public var description: String {
        var desc: [String] = []
        desc.append("HTTP/\(version.major).\(version.minor) \(status.code) \(status.reasonPhrase)")
        desc.append(headers.debugDescription)
        desc.append(body.description)
        return desc.joined(separator: "\n")
    }
    
    // MARK: Init
    
    /// Creates a new `HTTPResponse`.
    ///
    ///     let httpRes = HTTPResponse(status: .ok)
    ///
    /// - parameters:
    ///     - status: `HTTPResponseStatus` to use. This defaults to `HTTPResponseStatus.ok`
    ///     - version: `HTTPVersion` of this response, should usually be (and defaults to) 1.1.
    ///     - headers: `HTTPHeaders` to include with this response.
    ///                Defaults to empty headers.
    ///                The `"Content-Length"` and `"Transfer-Encoding"` headers will be set automatically.
    ///     - body: `HTTPBody` for this response, defaults to an empty body.
    ///             See `LosslessHTTPBodyRepresentable` for more information.
    public init(
        status: HTTPResponseStatus = .ok,
        version: HTTPVersion = .init(major: 1, minor: 1),
        headers: HTTPHeaders = .init(),
        body: LosslessHTTPBodyRepresentable = HTTPBody()
        ) {
        let head = HTTPResponseHead(version: version, status: status, headers: headers)
        self.init(
            head: head,
            body: body.convertToHTTPBody(),
            channel: nil
        )
        updateTransportHeaders()
    }
    
    /// Internal init that creates a new `HTTPResponse` without sanitizing headers.
    public init(head: HTTPResponseHead, body: HTTPBody, channel: Channel?) {
        self.head = head
        self.body = body
        self.channel = channel
    }
}


public protocol HTTPMessage: CustomStringConvertible, CustomDebugStringConvertible {
    /// The HTTP version of this message.
    var version: HTTPVersion { get set }
    
    /// The HTTP headers.
    var headers: HTTPHeaders { get set }
    
    /// The optional HTTP body.
    var body: HTTPBody { get set }
    
    /// If this message came from an NIO pipeline, the `Channel` property
    /// may be set. Use this to access things like the allocator or address.
    var channel: Channel? { get }
}

extension HTTPMessage {
    /// `MediaType` specified by this message's `"Content-Type"` header.
    public var contentType: MediaType? {
        get { return headers.firstValue(name: .contentType).flatMap(MediaType.parse) }
        set {
            if let new = newValue?.serialize() {
                headers.replaceOrAdd(name: .contentType, value: new)
            } else {
                headers.remove(name: .contentType)
            }
        }
    }
    
    /// Returns a collection of `MediaTypePreference`s specified by this HTTP message's `"Accept"` header.
    ///
    /// You can returns all `MediaType`s in this collection to check membership.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    /// Or you can compare preferences for two `MediaType`s.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public var accept: [MediaTypePreference] {
        return headers.firstValue(name: .accept).flatMap([MediaTypePreference].parse) ?? []
    }
    
    /// See `CustomDebugStringConvertible`
    public var debugDescription: String {
        return description
    }
    
    /// Updates transport headers for current body.
    /// This should be called automatically be `HTTPRequest` and `HTTPResponse` when their `body` property is set.
    internal mutating func updateTransportHeaders() {
        if let count = body.count?.description {
            headers.remove(name: .transferEncoding)
            if count != headers[.contentLength].first {
                headers.replaceOrAdd(name: .contentLength, value: count)
            }
        } else {
            headers.remove(name: .contentLength)
            if headers[.transferEncoding].first != "chunked" {
                headers.replaceOrAdd(name: .transferEncoding, value: "chunked")
            }
        }
    }
}

public struct HTTPCookies: ExpressibleByDictionaryLiteral {
    /// Internal storage.
    private var cookies: [String: HTTPCookieValue]
    
    /// Creates an empty `HTTPCookies`
    public init() {
        self.cookies = [:]
    }
    
    // MARK: Parse
    
    /// Parses a `Request` cookie
    public static func parse(cookieHeader: String) -> HTTPCookies? {
        var cookies: HTTPCookies = [:]
        
        // cookies are sent separated by semicolons
        let tokens = cookieHeader.components(separatedBy: ";")
        
        for token in tokens {
            // If a single deserialization fails, the cookies are malformed
            guard let (name, value) = HTTPCookieValue.parse(token) else {
                return nil
            }
            
            cookies[name] = value
        }
        
        return cookies
    }
    
    /// Parses a `Response` cookie
    public static func parse(setCookieHeaders: [String]) -> HTTPCookies? {
        var cookies: HTTPCookies = [:]
        
        for token in setCookieHeaders {
            // If a single deserialization fails, the cookies are malformed
            guard let (name, value) = HTTPCookieValue.parse(token) else {
                return nil
            }
            
            cookies[name] = value
        }
        
        return cookies
    }
    
    /// See `ExpressibleByDictionaryLiteral`.
    public init(dictionaryLiteral elements: (String, HTTPCookieValue)...) {
        var cookies: [String: HTTPCookieValue] = [:]
        for (name, value) in elements {
            cookies[name] = value
        }
        self.cookies = cookies
    }
    
    // MARK: Serialize
    
    /// Seriaizes the `Cookies` for a `Request`
    public func serialize(into request: inout HTTPRequest) {
        guard !cookies.isEmpty else {
            request.headers.remove(name: .cookie)
            return
        }
        
        let cookie: String = cookies.map { (name, value) in
            return "\(name)=\(value.string)"
            }.joined(separator: "; ")
        
        request.headers.replaceOrAdd(name: .cookie, value: cookie)
    }
    
    /// Seriaizes the `Cookies` for a `Response`
    public func serialize(into response: inout HTTPResponse)  {
        guard !cookies.isEmpty else {
            response.headers.remove(name: .setCookie)
            return
        }
        
        for (name, value) in cookies {
            response.headers.add(name: .setCookie, value: value.serialize(name: name))
        }
    }
    
    // MARK: Access
    
    /// Access `HTTPCookies` by name
    public subscript(name: String) -> HTTPCookieValue? {
        get { return cookies[name] }
        set { cookies[name] = newValue }
    }
}
