//
//  Config.swift
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

/**
 * Collection pre-defined ODIN gateway URLs.
 */
public enum OdinGatewayUrl: String {
    case production = "https://gateway.odin.4players.io"
}

/**
 * Collection of possible audio autopilot modes for a room.
 */
public enum OdinAudioAutopilotMode {
    /**
     * Remote medias need to be handled manually.
     */
    case off
    /**
     * Remote medias will be added to the capture/playback mix as a single mixed stream.
     */
    case room
    /**
     * Remote medias will be added to the capture/playback mix individually.
     */
    case media
}

/**
 * Collection of functions to handle audio configuration.
 */
enum OdinAudioConfig {
    /**
     * Returns the preferred audio format used for audio I/O.
     */
    static func format() -> AVAudioFormat {
        return AVAudioFormat(
            commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
            sampleRate: 48000.0,
            channels: 1,
            interleaved: true
        )!
    }
}
