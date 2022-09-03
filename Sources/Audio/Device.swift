//
//  Device.swift
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
 * Struct for audio device handling.
 */
public struct OdinAudioDevice: Equatable, Hashable {
    /**
     * The UID of the audio device.
     */
    public let uid: String

    /**
     * Initializes the audio device using a specified UID.
     */
    init(_ uid: String) {
        self.uid = uid
    }

    /**
     * The ID of the audio device.
     */
    public var id: UInt32 {
#if os(macOS)
        let objectId = AudioObjectID(kAudioObjectSystemObject)

        guard let address = OdinAudio.sharedInstance().getPropertyAddress(objectId, selector: kAudioHardwarePropertyDeviceForUID) else {
            return 0
        }

        var deviceId = kAudioObjectUnknown
        var devUidCf = self.uid as CFString

        let result: OSStatus = withUnsafeMutablePointer(to: &devUidCf) { devUidCfPtr in
            withUnsafeMutablePointer(to: &deviceId) { deviceIdPtr in
                var translation = AudioValueTranslation(
                    mInputData: devUidCfPtr,
                    mInputDataSize: UInt32(MemoryLayout<CFString>.size),
                    mOutputData: deviceIdPtr,
                    mOutputDataSize: UInt32(MemoryLayout<AudioObjectID>.size)
                )

                return OdinAudio.sharedInstance().getPropertyData(objectId, address: address, value: &translation)
            }
        }

        guard noErr == result else {
            return 0
        }

        return deviceId
#else
        return 0
#endif
    }

    /**
     * The name of the audio device.
     */
    public var name: String {
#if os(macOS)
        guard let address = OdinAudio.sharedInstance().getPropertyAddress(self.id, selector: kAudioDevicePropertyDeviceNameCFString) else {
            return ""
        }

        var name: CFString?
        guard noErr == OdinAudio.sharedInstance().getPropertyData(self.id, address: address, value: &name) else {
            return ""
        }

        return (name ?? "") as NSString as String
#else
        guard let port = OdinAudio.sharedInstance().getPortByUid(self.uid) else {
            return ""
        }

        return port.portName
#endif
    }

    /**
     * The sample rate of the audio device.
     */
    public var sampleRate: Double {
#if os(macOS)
        guard let address = OdinAudio.sharedInstance().getPropertyAddress(self.id, selector: kAudioDevicePropertyNominalSampleRate) else {
            return 0
        }

        var sampleRate: Double = 0
        guard noErr == OdinAudio.sharedInstance().getPropertyData(self.id, address: address, value: &sampleRate) else {
            return 0
        }

        return sampleRate
#else
        return AVAudioSession.sharedInstance().sampleRate
#endif
    }

    /**
     * The number of input channels provided by this audio device.
     *
     * Note: On iOS, this will just return the channel count of the current `AVAudioSession` input node to identify a
     *       device as being able to handle input.
     */
    public var inputChannels: UInt32 {
#if os(macOS)
        guard var address = OdinAudio.sharedInstance().getPropertyAddress(self.id, selector: kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput) else {
            return 0
        }

        var data: ExpressibleByNilLiteral?
        var size: UInt32 = 0
        guard noErr == OdinAudio.sharedInstance().getPropertyDataSize(self.id, address: address, dataSize: 0, data: &data, size: &size) else {
            return 0
        }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        guard noErr == AudioObjectGetPropertyData(self.id, &address, 0, nil, &size, bufferList) else {
            return 0
        }

        var numChan = UInt32(0)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for i in 0 ..< buffers.count {
            numChan += buffers[i].mNumberChannels
        }

        return numChan
#else
        guard (AVAudioSession.sharedInstance().availableInputs ?? []).first(where: { $0.uid == self.uid }) != nil else {
            return 0
        }

        return OdinAudio.sharedInstance().engine.inputNode.inputFormat(forBus: 0).channelCount
#endif
    }

    /**
     * The number of output channels provided by this audio device.
     *
     * Note: On iOS, this will just return the channel count of the current `AVAudioSession` output node to identify a
     *       device as being able to handle output.
     */
    public var outputChannels: UInt32 {
#if os(macOS)
        guard var address = OdinAudio.sharedInstance().getPropertyAddress(self.id, selector: kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeOutput) else {
            return 0
        }

        var data: ExpressibleByNilLiteral?
        var size: UInt32 = 0
        guard noErr == OdinAudio.sharedInstance().getPropertyDataSize(self.id, address: address, dataSize: 0, data: &data, size: &size) else {
            return 0
        }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        guard noErr == AudioObjectGetPropertyData(self.id, &address, 0, nil, &size, bufferList) else {
            return 0
        }

        var numChan = UInt32(0)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for i in 0 ..< buffers.count {
            numChan += buffers[i].mNumberChannels
        }

        return numChan
#else
        guard AVAudioSession.sharedInstance().currentRoute.outputs.first(where: { $0.uid == self.uid }) != nil else {
            return 0
        }

        return OdinAudio.sharedInstance().engine.outputNode.outputFormat(forBus: 0).channelCount
#endif
    }

    /**
     * Indicates whether or not this is an input device.
     */
    public var isInput: Bool {
        return self.inputChannels > 0
    }

    /**
     * Indicates whether or not this is an output device.
     */
    public var isOutput: Bool {
        return self.outputChannels > 0
    }
}
