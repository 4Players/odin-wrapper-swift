//
//  Room.swift
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

public protocol OdinRoomDelegate: AnyObject {
    /**
     * Callback for internal room connectivity state changes.
     */
    func onRoomConnectionStateChanged(
        room: OdinRoom,
        oldState: OdinRoomConnectionState,
        newState: OdinRoomConnectionState,
        reason: OdinRoomConnectionStateChangeReason
    )
    
    /**
     * Callback for when a room was joined and the initial state is fully available.
     */
    func onRoomJoined(
        room: OdinRoom
    )
    
    /**
     * Callback for room user data changes.
     */
    func onRoomUserDataChanged(
        room: OdinRoom
    )
    
    /**
     * Callback for peers joining the room.
     */
    func onPeerJoined(
        room: OdinRoom,
        peer: OdinPeer
    )
    
    /**
     * Callback for peer user data changes.
     */
    func onPeerUserDataChanged(
        room: OdinRoom,
        peer: OdinPeer
    )
    
    /**
     * Callback for peers leaving the room.
     */
    func onPeerLeft(
        room: OdinRoom,
        peer: OdinPeer
    )
    
    /**
     * Callback for medias being added to the room.
     */
    func onMediaAdded(
        room: OdinRoom,
        peer: OdinPeer,
        media: OdinMedia
    )
    
    /**
     * Callback for media activity state changes.
     */
    func onMediaActiveStateChanged(
        room: OdinRoom,
        peer: OdinPeer,
        media: OdinMedia
    )
    
    /**
     * Callback for medias being removed from the room.
     */
    func onMediaRemoved(
        room: OdinRoom,
        peer: OdinPeer,
        media: OdinMedia
    )
    
    /**
     * Callback for incoming arbitrary data messages.
     */
    func onMessageReceived(
        room: OdinRoom,
        senderId: UInt64,
        data: [UInt8]
    )
}
