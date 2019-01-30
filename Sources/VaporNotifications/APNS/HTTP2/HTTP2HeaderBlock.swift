//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import CNIONghttp2
import NIO
import NIOHTTP1


// MARK:- Helpers for working with nghttp2 headers.
internal extension HTTPHeaders {
    /// Creates a NGHTTP2 header block for this HTTP/2 HEADERS frame.
    ///
    /// This function will handle placing in the appropriate pseudo-headers
    /// for HTTP/2 usage and obeying the ordering rules for those headers.
    internal func withNGHTTP2Headers<T>(allocator: ByteBufferAllocator,
                                        _ body: (UnsafePointer<nghttp2_nv>, Int) -> T) -> T {
        var headerBlock = ContiguousHeaderBlock(buffer: allocator.buffer(capacity: 1024))
        self.writeHeaders(into: &headerBlock)

        var nghttpNVs: [nghttp2_nv] = []
        nghttpNVs.reserveCapacity(headerBlock.headerIndices.count)
        return headerBlock.headerBuffer.withUnsafeMutableReadableBytes { ptr in
            let base = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            for (hnBegin, hnLen, hvBegin, hvLen) in headerBlock.headerIndices {
                nghttpNVs.append(nghttp2_nv(name: base + hnBegin,
                                            value: base + hvBegin,
                                            namelen: hnLen,
                                            valuelen: hvLen,
                                            flags: 0))
            }
            return nghttpNVs.withUnsafeMutableBufferPointer { nvPtr in
                body(nvPtr.baseAddress!, nvPtr.count)
            }
        }
    }

    /// Writes the header block.
    ///
    /// This function writes the headers corresponding to this type of header block into a byte
    /// buffer, recording their indices. This includes writing out any pseudo-headers that are
    /// needed to the start of the buffer.
    private func writeHeaders(into headerBlock: inout ContiguousHeaderBlock) {
        // TODO(cory): Right now this method is a bit costly, we should add helpers to
        // HTTPHeaders to make it faster (and ideally end up removing ContiguousHeaderBlock).
        // TODO(cory): Would be great to get the bytes for these names! In fact, this entire
        // method would work better if I could just shuffle the header ordering around without
        // copying anything.
        // chr(58) is ":"
        var headers = self

        let pseudoHeaders = headers.map { $0.name }.filter { $0.utf8.first == 58 }
        for header in pseudoHeaders {
            let value = headers.popPseudoHeader(name: header)!
            headerBlock.writeHeader(name: header, value: value)
        }

        headers.forEach{ headerBlock.writeHeader(name: $0.name, value: $0.value) }
    }
}

/// A `ContiguousHeaderBlock` is a series of HTTP headers, written
/// out in name-value order into the same contiguous chunk of memory.
///
/// For now, this exists basically solely because we can't get access to the memory used
/// by the HTTP/1 `HTTPHeaders` structure, and to provide us some convenience methods.
private struct ContiguousHeaderBlock {
    var headerBuffer: ByteBuffer
    var headerIndices: [(Int, Int, Int, Int)] = []

    init(buffer: ByteBuffer) {
        self.headerBuffer = buffer
    }

    /// Writes the given name/value pair into the header block and records where we
    /// wrote it.
    mutating func writeHeader(name: String, value: String) {
        let headerNameBegin = self.headerBuffer.writerIndex
        let headerNameLen = self.headerBuffer.write(string: name)!
        let headerValueBegin = self.headerBuffer.writerIndex
        let headerValueLen = self.headerBuffer.write(string: value)!
        self.headerIndices.append((headerNameBegin, headerNameLen, headerValueBegin, headerValueLen))
    }
}

// MARK:- Methods for creating `HTTPRequestHead`/`HTTPResponseHead` objects from header blocks generated by nghttp2.
internal extension HTTPRequestHead {
    /// Create a `HTTPRequestHead` from the header block produced by nghttp2.
    init(http2HeaderBlock headers: HTTPHeaders) {
        // Take a local copy here.
        var headers = headers

        // A request head should have only up to four psuedo-headers. We strip them off.
        // TODO(cory): Error handling!
        let method = HTTPMethod(methodString: headers.popPseudoHeader(name: ":method")!)
        let version = HTTPVersion(major: 2, minor: 0)
        let uri = headers.popPseudoHeader(name: ":path")!

        // TODO(cory): Right now we're just stripping authority, but it should probably
        // be used.
        headers.remove(name: ":scheme")

        // This block works only if the HTTP/2 implementation rejects requests with
        // mismatched :authority and host headers.
        let authority = headers.popPseudoHeader(name: ":authority")!
        if !headers.contains(name: "host") {
            headers.add(name: "host", value: authority)
        }

        self.init(version: version, method: method, uri: uri)
        self.headers = headers
    }
}

internal extension HTTPResponseHead {
    /// Create a `HTTPResponseHead` from the header block produced by nghttp2.
    init(http2HeaderBlock headers: HTTPHeaders) {
        // Take a local copy here.
        var headers = headers

        // A response head should have only one psuedo-header. We strip it off.
        // TODO(cory): Error handling!
        let status = HTTPResponseStatus(statusCode: Int(headers.popPseudoHeader(name: ":status")!, radix: 10)!)
        self.init(version: .init(major: 2, minor: 0), status: status, headers: headers)
    }
}

private extension HTTPHeaders {
    /// Grabs a pseudo-header from a header block and removes it from that block.
    ///
    /// - parameter:
    ///     - name: The header name to remove.
    /// - returns: The array of values for this pseudo-header, or `nil` if the header
    ///     is not in the block.
    mutating func popPseudoHeader(name: String) -> String? {
        // TODO(cory): This should be upstreamed becuase right now we loop twice instead
        // of once.
        let value = self[name]
        if value.count == 1 {
            self.remove(name: name)
            return value.first!
        }
        // TODO(cory): Proper error handling here please.
        precondition(value.count == 0, "ETOOMANYPSEUDOHEADERVALUES")
        return nil
    }
}

private extension HTTPMethod {
    /// Create a `HTTPMethod` from the string representation of that method.
    init(methodString: String) {
        switch methodString {
        case "GET":
            self = .GET
        case "PUT":
            self = .PUT
        case "ACL":
            self = .ACL
        case "HEAD":
            self = .HEAD
        case "POST":
            self = .POST
        case "COPY":
             self = .COPY
        case "LOCK":
            self = .LOCK
        case "MOVE":
            self = .MOVE
        case "BIND":
            self = .BIND
        case "LINK":
            self = .LINK
        case "PATCH":
            self = .PATCH
        case "TRACE":
            self = .TRACE
        case "MKCOL":
            self = .MKCOL
        case "MERGE":
            self = .MERGE
        case "PURGE":
            self = .PURGE
        case "NOTIFY":
            self = .NOTIFY
        case "SEARCH":
            self = .SEARCH
        case "UNLOCK":
            self = .UNLOCK
        case "REBIND":
            self = .REBIND
        case "UNBIND":
            self = .UNBIND
        case "REPORT":
            self = .REPORT
        case "DELETE":
            self = .DELETE
        case "UNLINK":
            self = .UNLINK
        case "CONNECT":
            self = .CONNECT
        case "MSEARCH":
            self = .MSEARCH
        case "OPTIONS":
            self = .OPTIONS
        case "PROPFIND":
            self = .PROPFIND
        case "CHECKOUT":
            self = .CHECKOUT
        case "PROPPATCH":
            self = .PROPPATCH
        case "SUBSCRIBE":
            self = .SUBSCRIBE
        case "MKCALENDAR":
            self = .MKCALENDAR
        case "MKACTIVITY":
            self = .MKACTIVITY
        case "UNSUBSCRIBE":
            self = .UNSUBSCRIBE
        default:
            self = .RAW(value: methodString)
        }
    }
}

internal extension String {
    /// Create a `HTTPMethod` from the string representation of that method.
    init(httpMethod: HTTPMethod) {
        switch httpMethod {
        case .GET:
            self = "GET"
        case .PUT:
            self = "PUT"
        case .ACL:
            self = "ACL"
        case .HEAD:
            self = "HEAD"
        case .POST:
            self = "POST"
        case .COPY:
            self = "COPY"
        case .LOCK:
            self = "LOCK"
        case .MOVE:
            self = "MOVE"
        case .BIND:
            self = "BIND"
        case .LINK:
            self = "LINK"
        case .PATCH:
            self = "PATCH"
        case .TRACE:
            self = "TRACE"
        case .MKCOL:
            self = "MKCOL"
        case .MERGE:
            self = "MERGE"
        case .PURGE:
            self = "PURGE"
        case .NOTIFY:
            self = "NOTIFY"
        case .SEARCH:
            self = "SEARCH"
        case .UNLOCK:
            self = "UNLOCK"
        case .REBIND:
            self = "REBIND"
        case .UNBIND:
            self = "UNBIND"
        case .REPORT:
            self = "REPORT"
        case .DELETE:
            self = "DELETE"
        case .UNLINK:
            self = "UNLINK"
        case .CONNECT:
            self = "CONNECT"
        case .MSEARCH:
            self = "MSEARCH"
        case .OPTIONS:
            self = "OPTIONS"
        case .PROPFIND:
            self = "PROPFIND"
        case .CHECKOUT:
            self = "CHECKOUT"
        case .PROPPATCH:
            self = "PROPPATCH"
        case .SUBSCRIBE:
            self = "SUBSCRIBE"
        case .MKCALENDAR:
            self = "MKCALENDAR"
        case .MKACTIVITY:
            self = "MKACTIVITY"
        case .UNSUBSCRIBE:
            self = "UNSUBSCRIBE"
        case .RAW(let v):
            self = v
        }
    }
}

