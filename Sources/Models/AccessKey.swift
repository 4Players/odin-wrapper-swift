//
//  AccessKey.swift
//
//  Copyright (c) 2022 4Players GmbH (http://www.4players.io)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Odin

/**
 * Class to handle ODIN access keys.
 *
 * An access key is a 44 character long Base64-String, which consists of a version, random bytes and a checksum.
 */
public class OdinAccessKey {
    /**
     * The underlying access key as a string.
     */
    public let rawValue: String

    /**
     * A pointer to a local token generator used to generate signed room tokens based based on an access key. Please
     * note, that access keys are your the unique authentication keys to be used to generate room tokens for accessing
     * the ODIN server network. For your own security, we strongly recommend that you _NEVER_ put an access key in your
     * client code and generate room tokens on a server.
     */
    internal let tokenGenerator: OpaquePointer!

    /**
     * Initializes a new access key instance.
     */
    public convenience init() {
        try! self.init(nil)
    }

    /**
     * Initializes an access key instance using an existing access key string.
     */
    public init(_ string: String?) throws {
        if let string = string {
            self.rawValue = string
        } else {
            let maxLength = Int(odin_access_key_generate(nil, 0))
            var outBuffer = [CChar](repeating: 0, count: maxLength)

            let returnCode = odin_access_key_generate(&outBuffer, maxLength)
            try OdinResult.validate(returnCode)

            self.rawValue = String(cString: &outBuffer)
        }

        self.tokenGenerator = odin_token_generator_create(self.rawValue)

        if self.tokenGenerator == nil {
            throw OdinResult.error("failed to create token generator; access key is invalid")
        }
    }

    /**
     * Destroys the underlying token generator instance.
     */
    deinit {
        odin_token_generator_destroy(self.tokenGenerator)
    }

    /**
     * Uses the internal token generator to create a signed JWT based of this access key, which can be used by a client
     * to join a room.
     */
    public func generateToken(roomId: String, userId: String? = "") throws -> OdinToken {
        let maxLength = Int(odin_token_generator_create_token(self.tokenGenerator, roomId, userId, nil, 0))
        var outBuffer = [CChar](repeating: 0, count: maxLength)

        let returnCode = odin_token_generator_create_token(self.tokenGenerator, roomId, userId, &outBuffer, maxLength)
        try OdinResult.validate(returnCode)

        return try OdinToken(String(cString: &outBuffer))
    }

    /**
     * The key ID of the access key. This is included in room tokens, making it possible to identify which public key
     * must be used for verification.
     */
    public var id: String {
        get throws {
            let maxLength = Int(odin_access_key_id(self.rawValue, nil, 0))
            var outBuffer = [CChar](repeating: 0, count: maxLength)

            let returnCode = odin_access_key_id(self.rawValue, &outBuffer, maxLength)
            try OdinResult.validate(returnCode)

            return String(cString: &outBuffer)
        }
    }

    /**
     * The public key of the access key. The public key is based on the Ed25519 curve and must be submitted to 4Players
     * so that a generated room token can be verified.
     */
    public var publicKey: String {
        get throws {
            let maxLength = Int(odin_access_key_public_key(self.rawValue, nil, 0))
            var outBuffer = [CChar](repeating: 0, count: maxLength)

            let returnCode = odin_access_key_public_key(self.rawValue, &outBuffer, maxLength)
            try OdinResult.validate(returnCode)

            return String(cString: &outBuffer)
        }
    }

    /**
     * The secret key of the access key. The secret key is based on the Ed25519 curve and used to sign a generated room
     * token to access the ODIN network.
     */
    public var secretKey: String {
        get throws {
            let maxLength = Int(odin_access_key_secret_key(self.rawValue, nil, 0))
            var outBuffer = [CChar](repeating: 0, count: maxLength)

            let returnCode = odin_access_key_secret_key(self.rawValue, &outBuffer, maxLength)
            try OdinResult.validate(returnCode)

            return String(cString: &outBuffer)
        }
    }
}
