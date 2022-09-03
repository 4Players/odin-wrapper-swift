//
//  Token.swift
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

import Foundation

/**
 * Class to handle ODIN tokens.
 *
 * A room token is a JWT given to clients that allows them to connect to a chat room in the ODIN network.
 */
public class OdinToken {
    /**
     * The underlying JWT as a string.
     */
    public let rawValue: String
    
    /**
     * The unserialized JSON payload of the token.
     */
    private let payload: [String: Any]
    
    /**
     * Initializes a new token instance using a specified JWT string.
     */
    public init(_ string: String) throws {
        self.rawValue = string
        
        let segments = rawValue.components(separatedBy: ".")
        
        guard segments.count > 1 else {
            throw OdinResult.error("failed to decode JWT payload; token is invalid")
        }
        
        let base64 = segments[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        
        guard let data = Data(base64Encoded: padded) else {
            throw OdinResult.error("failed to decode JWT payload; token is invalid")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw OdinResult.error("failed to decode JWT payload; token is invalid")
        }
        
        self.payload = json
    }
    
    /**
     * The user ID that was encoded in the token.
     */
    public var userId: String {
        get throws {
            guard let userId = payload["uid"] as? String else {
                throw OdinResult.error("failed to get user id from token; uid is missing")
            }
            
            return userId
        }
    }
    
    /**
     * The room ID that was encoded in the token.
     */
    public var roomId: String {
        get throws {
            guard let roomId = payload["rid"] as? String else {
                throw OdinResult.error("failed to get room id from token; rid is missing")
            }
            
            return roomId
        }
    }
}
