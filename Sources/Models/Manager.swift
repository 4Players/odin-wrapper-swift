//
//  Manager.swift
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
 * Class to help managing a collection of ODIN rooms.
 */
public class OdinManager {
    /**
     * An array of current room instances.
     */
    @Published public private(set) var rooms: [String: OdinRoom] = [:]

    /**
     * Creates a shared instance of the manager.
     */
    private static var shared: OdinManager = .init()

    /**
     * Adds the specified room to the list of known room instances.
     */
    internal func registerRoom(_ room: OdinRoom) {
        self.rooms.updateValue(room, forKey: room.id)
    }

    /**
     * Removes the specified room from the list of known room instances.
     */
    internal func unregisterRoom(_ room: OdinRoom) {
        self.rooms.removeValue(forKey: room.id)
    }

    /**
     * Returns a shared instance of the manager.
     */
    public class func sharedInstance() -> OdinManager {
        return self.shared
    }
}
