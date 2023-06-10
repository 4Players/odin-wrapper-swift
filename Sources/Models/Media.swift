//
//  Media.swift
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

import AVFoundation
import Foundation
import Odin

/**
 * Class to handle ODIN media.
 *
 * A media represents an audio stream that was added to an ODIN room by a peer.
 */
public class OdinMedia: Hashable, ObservableObject {
    /**
     * The underlying media stream handle to interact with.
     */
    public internal(set) var streamHandle: OdinMediaStreamHandle
    
    /**
     * The underlying object that supplies/receives audio data on the media stream.
     */
    public internal(set) var audioNode: AVAudioNode!

    /**
     * Indicates for whether or not the media stream is sending/receiving data.
     */
    @Published public internal(set) var activityStatus: Bool = false

    /**
     * Initializes a new media instance of type audio using pre-defined settings.
     */
    init(_ audioConfig: OdinAudioStreamConfig) throws {
        self.streamHandle = odin_audio_stream_create(audioConfig)
        
        if self.streamHandle == 0 {
            throw OdinResult.error("failed to create media stream; audio config is invalid")
        }
        
        if self.type != OdinMediaStreamType_Audio {
            throw OdinResult.error("failed to create media stream; type is invalid")
        }
        
        self.audioNode = AVAudioSinkNode { [unowned self] _, frameCount, audioBufferList -> OSStatus in
            let buffer = UnsafeBufferPointer<Float>(audioBufferList.pointee.mBuffers)

            do {
                try self.push(buffer: buffer, frameCount: frameCount)
            } catch {
                return kAudioCodecIllegalOperationError
            }
            
            return noErr
        }
    }
    
    /**
     * Initializes a new media instance using an existing media stream handle.
     */
    init(_ streamHandle: OdinMediaStreamHandle) throws {
        self.streamHandle = streamHandle
        
        if self.type == OdinMediaStreamType_Invalid {
            throw OdinResult.error("failed to create media stream; type is invalid")
        }
        
        self.audioNode = AVAudioSourceNode(
            format: OdinAudioConfig.format(),
            renderBlock: { [unowned self] _, _, frameCount, audioBufferList -> OSStatus in
                let buffer = UnsafeMutableBufferPointer<Float>(audioBufferList.pointee.mBuffers)
                
                do {
                    try self.read(buffer: buffer, frameCount: frameCount)
                } catch {
                    return kAudioCodecIllegalOperationError
                }
                
                return noErr
            }
        )
    }
    
    /**
     * Destroys the media stream if necessary.
     */
    deinit {
        if self.streamHandle != 0 {
            try? self.destroy()
        }
    }

    /**
     * Destroys the underlying media stream handle and removes it from the room after which you will no longer be able
     * to receive or send any data over it.
     */
    func destroy() throws {
        self.audioNode.engine?.detach(self.audioNode)
        
        let returnCode = odin_media_stream_destroy(self.streamHandle)
        try OdinResult.validate(returnCode)
        
        self.streamHandle = 0
    }

    /**
     * Sends data to the audio stream. The data has to be interleaved [-1, 1] float data.
     */
    private func push(buffer: UnsafeBufferPointer<Float>, frameCount: UInt32) throws {
        let returnCode = odin_audio_push_data(self.streamHandle, buffer.baseAddress, Int(frameCount))
        try OdinResult.validate(returnCode)
    }
    
    /**
     * Reads audio data from the specified `OdinMediaStream`. This will return audio data in 48kHz interleaved.
     */
    private func read(buffer: UnsafeMutableBufferPointer<Float>, frameCount: UInt32) throws {
        let returnCode = odin_audio_read_data(self.streamHandle, buffer.baseAddress, Int(frameCount))
        try OdinResult.validate(returnCode)
    }
    
    /**
     * The ID of the media stream.
     */
    public var id: UInt16 {
        let count = 1
        let mediaId = UnsafeMutablePointer<UInt16>.allocate(capacity: count)
        mediaId.initialize(repeating: 0, count: count)
            
        defer {
            mediaId.deinitialize(count: count)
            mediaId.deallocate()
        }
            
        let returnCode = odin_media_stream_media_id(self.streamHandle, mediaId)
            
        return odin_is_error(returnCode) ? 0 : mediaId.pointee
    }

    /**
     * The ID of the peer that owns the media stream.
     *
     * Note: This will always be `0` if the media is owned by your own peer.
     */
    public var peerId: UInt64 {
        get throws {
            let count = 1
            let peerId = UnsafeMutablePointer<UInt64>.allocate(capacity: count)
            peerId.initialize(repeating: 0, count: count)
            
            defer {
                peerId.deinitialize(count: count)
                peerId.deallocate()
            }
            
            let returnCode = odin_media_stream_peer_id(self.streamHandle, peerId)
            try OdinResult.validate(returnCode)
            
            return peerId.pointee
        }
    }
    
    /**
     * Statistics for the media stream handle.
     *
     * Note: This is only available for output streams.
     */
    public var streamStats: OdinAudioStreamStats {
        let count = 1
        let stats = UnsafeMutablePointer<OdinAudioStreamStats>.allocate(capacity: count)
        stats.initialize(repeating: OdinAudioStreamStats(), count: count)

        let returnCode = odin_audio_stats(self.streamHandle, stats)
        return odin_is_error(returnCode) ? OdinAudioStreamStats() : stats.pointee
    }
    
    /**
     * Indicates whether or not this media is owned by a remote peer.
     */
    public var remote: Bool {
        return self.audioNode is AVAudioSourceNode
    }

    /**
     * The type of the specified media stream.
     */
    public var type: OdinMediaStreamType {
        return odin_media_stream_type(self.streamHandle)
    }
    
    /**
     * Hashes the essential components of the media by feeding them into the given hasher.
     */
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /**
     * Returns a value indicating whether two type-erased hashable instances wrap the same media.
     */
    public static func ==(lhs: OdinMedia, rhs: OdinMedia) -> Bool {
        return lhs === rhs
    }
}
