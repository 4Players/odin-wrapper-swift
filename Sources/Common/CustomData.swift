//
//  CustomData.swift
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
 * Collection of helper functions to handle ODIN user data.
 */
public enum OdinCustomData {
    /**
     * Converts a string to a byte array.
     */
    public static func encode(_ string: String) -> [UInt8] {
        return Array(string.utf8)
    }

    /**
     * Converts a byte array to a string.
     */
    public static func decode(_ bytes: [UInt8]) -> String {
        return String(decoding: bytes, as: UTF8.self)
    }
    
    /**
     * Converts a codable type to a byte array.
     */
    public static func encode<T: Encodable>(_ codable: T) -> [UInt8] {
        let encoder = JSONEncoder()
        
        guard let json = try? encoder.encode(codable) else {
            return []
        }
        
        guard let string = String(data: json, encoding: String.Encoding.utf8) else {
            return []
        }
        
        return self.encode(string)
    }
    
    /**
     * Converts a byte array to a codable type.
     */
    public static func decode<T: Decodable>(_ bytes: [UInt8]) -> T? {
        let decoder = JSONDecoder()
        
        guard let data = self.decode(bytes).data(using: .utf8) else {
            return nil
        }
        
        guard let codable = try? decoder.decode(T.self, from: data) else {
            return nil
        }
        
        return codable
    }
}
