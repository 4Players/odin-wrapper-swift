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

/**
 * Allow APM configs being encodable and decodable for compatibility with external representations such as JSON.
 */
extension OdinApmConfig: Codable {
    /**
     * An authoritative list of properties that must be included when APM configs are encoded or decoded.
     */
    enum CodingKeys: String, CodingKey {
        case voice_activity_detection
        case voice_activity_detection_attack_probability
        case voice_activity_detection_release_probability
        case volume_gate
        case volume_gate_attack_loudness
        case volume_gate_release_loudness
        case echo_canceller
        case high_pass_filter
        case pre_amplifier
        case noise_suppression_level
        case transient_suppressor
        case gain_controller
    }

    /**
     * Encodes the APM config into the given encoder.
     */
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.voice_activity_detection, forKey: .voice_activity_detection)
        try container.encode(self.voice_activity_detection_attack_probability, forKey: .voice_activity_detection_attack_probability)
        try container.encode(self.voice_activity_detection_release_probability, forKey: .voice_activity_detection_release_probability)
        try container.encode(self.volume_gate, forKey: .volume_gate)
        try container.encode(self.volume_gate_attack_loudness, forKey: .volume_gate_attack_loudness)
        try container.encode(self.volume_gate_release_loudness, forKey: .volume_gate_release_loudness)
        try container.encode(self.echo_canceller, forKey: .echo_canceller)
        try container.encode(self.high_pass_filter, forKey: .high_pass_filter)
        try container.encode(self.pre_amplifier, forKey: .pre_amplifier)
        try container.encode(self.noise_suppression_level.rawValue, forKey: .noise_suppression_level)
        try container.encode(self.transient_suppressor, forKey: .transient_suppressor)
        try container.encode(self.gain_controller, forKey: .gain_controller)
    }

    /**
     * Creates a new APM config by decoding from the given decoder.
     */
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            voice_activity_detection: try values.decode(Bool.self, forKey: .voice_activity_detection),
            voice_activity_detection_attack_probability: try values.decode(Float.self, forKey: .voice_activity_detection_attack_probability),
            voice_activity_detection_release_probability: try values.decode(Float.self, forKey: .voice_activity_detection_release_probability),
            volume_gate: try values.decode(Bool.self, forKey: .volume_gate),
            volume_gate_attack_loudness: try values.decode(Float.self, forKey: .volume_gate_attack_loudness),
            volume_gate_release_loudness: try values.decode(Float.self, forKey: .volume_gate_release_loudness),
            echo_canceller: try values.decode(Bool.self, forKey: .echo_canceller),
            high_pass_filter: try values.decode(Bool.self, forKey: .high_pass_filter),
            pre_amplifier: try values.decode(Bool.self, forKey: .pre_amplifier),
            noise_suppression_level: OdinNoiseSuppressionLevel(rawValue: try values.decode(UInt32.self, forKey: .noise_suppression_level)),
            transient_suppressor: try values.decode(Bool.self, forKey: .transient_suppressor),
            gain_controller: try values.decode(Bool.self, forKey: .gain_controller)
        )
    }
}
