//
//  Signer.swift
//  App
//
//  Created by Halimjon Juraev on 3/24/18.
//

import Foundation
import Crypto
import JWT
import CNIOOpenSSL
import Bits
import NIO
import Vapor

class KeyUtilities {
    
    static func generateKeys(Path: String) -> (Data, Data){
        var pKey = EVP_PKEY_new()

        let fp = fopen(Path, "r")
        
        PEM_read_PrivateKey(fp, &pKey, nil, nil)
 
        let ecKey = EVP_PKEY_get1_EC_KEY(pKey)
        
        
        EC_KEY_set_conv_form(ecKey, POINT_CONVERSION_UNCOMPRESSED)
        fclose(fp)

        var pub: UnsafeMutablePointer<UInt8>? = nil
        let pub_len = i2o_ECPublicKey(ecKey, &pub)
        var publicKey = ""
        if let pub = pub {
            var publicBytes = Bytes(repeating: 0, count: Int(pub_len))
            for i in 0..<Int(pub_len) {
                publicBytes[i] = Byte(pub[i])
            }
            let publicData = Data(bytes: publicBytes)
            //            print("public key: \(publicData.hexString)")
            publicKey = publicData.hexEncodedString()
        } else {
            publicKey = ""
        }
        
        let bn = EC_KEY_get0_private_key(ecKey!)
        let privKeyBigNum = BN_bn2hex(bn)
        
        let privateKey = "00\(String.init(validatingUTF8: privKeyBigNum!)!)"
        
        let privData = dataFromHexadecimalString(key: privateKey)!
        let pubData = dataFromHexadecimalString(key: publicKey)!
        
        return (privData, pubData)
    }
    
    static func dataFromHexadecimalString(key: String) -> Data? {
        var data = Data(capacity: key.count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: key, options: [], range: NSMakeRange(0, key.count)) { match, flags, stop in
            let range = key.range(from: match!.range)

            let byteString = key[range!]
            var num = UInt8(byteString, radix: 16)
            data.append(&num!, count: 1)
        }
        
        return data
    }
}


public final class ES256: ECDSASigner {
    public func sign(_ plaintext: LosslessDataConvertible) throws -> Data {
        let digest = Bytes(try SHA256.digest(plaintext))
        
        
        let ecKey = try newECKeyPair()
        
        guard let signature = ECDSA_do_sign(digest, Int32(digest.count), ecKey) else {
            throw JWTErrors.signing
        }
        
        var derEncodedSignature: UnsafeMutablePointer<UInt8>? = nil
        let derLength = i2d_ECDSA_SIG(signature, &derEncodedSignature)
        
        guard let derCopy = derEncodedSignature, derLength > 0 else {
            throw JWTErrors.signing
        }
        
        var derBytes = [UInt8](repeating: 0, count: Int(derLength))
        
        for b in 0..<Int(derLength) {
            derBytes[b] = derCopy[b]
        }
        
        return Data(derBytes)
    }
    
    public var jwtAlgorithmName: String {
        return "ES256"
    }
    
    public func verify(_ signature: Data, signs plaintext: Data) throws -> Bool {
        var signaturePointer: UnsafePointer? = UnsafePointer(Bytes(signature))
        let signature = d2i_ECDSA_SIG(nil, &signaturePointer, signature.count)
        let digest = Bytes(try SHA256.digest(plaintext))
        let ecKey = try newECPublicKey()
        let result = ECDSA_do_verify(digest, Int32(digest.count), signature, ecKey)
        if result == 1 {
            return false
        }
        return true
    }

   
    
    
    public let curve = NID_X9_62_prime256v1
    public let key: Data
    
    public init(key: Data) {
        self.key = key
    }
}



public protocol ECDSASigner: JWTAlgorithm {
    var key: Data { get }
    var curve: Int32 { get }
}




fileprivate extension ECDSASigner {
    func newECKey() throws -> OpaquePointer {
        guard let ecKey = EC_KEY_new_by_curve_name(curve) else {
            throw JWTErrors.createKey
        }
        return ecKey
    }
    
    func newECKeyPair() throws -> OpaquePointer {
        var privateNum = BIGNUM()
        
        // Set private key
        
        BN_init(&privateNum)
        BN_bin2bn(Bytes(key), Int32(key.count), &privateNum)
        let ecKey = try newECKey()
        EC_KEY_set_private_key(ecKey, &privateNum)
        
        // Derive public key
        
        let context = BN_CTX_new()
        BN_CTX_start(context)
        
        let group = EC_KEY_get0_group(ecKey)
        let publicKey = EC_POINT_new(group)
        EC_POINT_mul(group, publicKey, &privateNum, nil, nil, context)
        EC_KEY_set_public_key(ecKey, publicKey)
        
        // Release resources
        
        EC_POINT_free(publicKey)
        BN_CTX_end(context)
        BN_CTX_free(context)
        BN_clear_free(&privateNum)
        
        return ecKey
    }
    
    func newECPublicKey() throws -> OpaquePointer {
        var ecKey: OpaquePointer? = try newECKey()
        var publicBytesPointer: UnsafePointer? = UnsafePointer<UInt8>(Bytes(key))
        
        if let ecKey = o2i_ECPublicKey(&ecKey, &publicBytesPointer, key.count) {
            return ecKey
        } else {
            throw JWTErrors.createPublicKey
        }
    }
    

}

enum JWTErrors: Error {
    case createKey
    case createPublicKey
    case decoding
    case encoding
    case incorrectNumberOfSegments
    case incorrectPayloadForClaimVerification
    case missingAlgorithm
    case missingClaim(withName: String)
    case privateKeyRequired
    case signatureVerificationFailed
    case signing
    case verificationFailedForClaim(withName: String)
    case wrongAlgorithm
    // allow for future additions
    case unknown(Error)
}

extension JWTSigner {
    /// Creates an HS256 JWT signer with the supplied key
    public static func es256(key: Data) -> JWTSigner {
        return JWTSigner(algorithm: ES256(key: key))
    }

}


extension JWT {
    
  
}

extension String {
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self)
            else { return nil }
        return from ..< to
    }
    
    func collapseWhitespace() -> String {
        let thecomponents = components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        return thecomponents.joined(separator: " ")
    }
    
    func between(_ left: String, _ right: String) -> String? {
        guard
            let leftRange = range(of:left), let rightRange = range(of: right, options: .backwards),
            left != right && leftRange.upperBound != rightRange.lowerBound
            else { return nil }
        
        return String(self[leftRange.upperBound...index(before: rightRange.lowerBound)])
        
    }
    
    func splitByLength(_ length: Int) -> [String] {
        var result = [String]()
        var collectedCharacters = [Character]()
        collectedCharacters.reserveCapacity(length)
        var count = 0
        
        for character in self {
            collectedCharacters.append(character)
            count += 1
            if (count == length) {
                // Reached the desired length
                count = 0
                result.append(String(collectedCharacters))
                collectedCharacters.removeAll(keepingCapacity: true)
            }
        }
        
        // Append the remainder
        if !collectedCharacters.isEmpty {
            result.append(String(collectedCharacters))
        }
        
        return result
    }
}
