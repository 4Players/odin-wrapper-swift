//
//  Result.swift
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
 * Collection of functions to handle ODIN return codes.
 */
public enum OdinResult: Error, CustomStringConvertible {
    /**
     * A function completed successfully.
     */
    case success

    /**
     * A function aborted with an error.
     */
    case error(String)

    /**
     * A function returned an integer value.
     */
    case value(UInt32)

    /**
     * A string representation of the result.
     */
    public var description: String {
        switch self {
        case let .error(error):
            return error
        default:
            return "ok"
        }
    }

    /**
     * Helper function that formats a specified return code using a set of pre-defined cases.
     */
    public static func format(_ code: UInt32) -> OdinResult {
        if odin_is_error(code) {
            let maxLength = odin_error_format(code, nil, 0)
            var outBuffer = [CChar](repeating: 0, count: maxLength)

            odin_error_format(code, &outBuffer, maxLength)
            return .error(String(cString: &outBuffer))
        }

        return code != 0 ? .value(code) : .success
    }

    /**
     * Helper function that validates a specified return code and throws an error if necessary.
     */
    public static func validate(_ code: UInt32) throws {
        let result = format(code)
        if case .error = result {
            throw result
        }
    }
}
