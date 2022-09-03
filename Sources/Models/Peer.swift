//
//  Peer.swift
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
 * Class to handle ODIN peers.
 *
 * A peer represents a client that has joined an ODIN room.
 */
public class OdinPeer: Hashable, ObservableObject {
    /**
     * The ID of the peer.
     */
    public internal(set) var id: UInt64

    /**
     * The user identifier of the peer specified during authentication.
     */
    public internal(set) var userId: String

    /**
     * A byte array with arbitrary user data attached to the peer.
     */
    @Published public internal(set) var userData: [UInt8]

    /**
     * An array of current medias of the peer.
     */
    @Published public internal(set) var medias: [OdinMediaStreamHandle: OdinMedia] = [:]

    /**
     * Initializes a new peer instance.
     */
    convenience init() {
        self.init(id: 0)
    }

    /**
     * Initializes a new peer instance using pre-defined data.
     */
    init(id: UInt64, userId: String = "", userData: [UInt8] = []) {
        self.id = id
        self.userId = userId
        self.userData = userData
    }

    /**
     * An array of current active medias of the peer.
     */
    public var activeMedias: [OdinMediaStreamHandle: OdinMedia] {
        return self.medias.filter { media in
            media.value.activityStatus
        }
    }

    /**
     * Hashes the essential components of the peer by feeding them into the given hasher.
     */
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /**
     * Returns a value indicating whether two type-erased hashable instances wrap the same peer.
     */
    public static func ==(lhs: OdinPeer, rhs: OdinPeer) -> Bool {
        return lhs === rhs
    }
}
