//
//  Base.swift
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
 * Class to help managing the core audio functionality.
 *
 * The `AVAudioEngine` instance manages audio nodes, controls playback and configures rendering constraints.
 */
public class OdinAudio {
    /**
     * The underlying `AVAudioEngine` instance.
     */
    public let engine: AVAudioEngine
    
    /**
     * Creates a shared instance of the audio engine.
     */
    private static var shared: OdinAudio = .init()
    
    /**
     * A list of audio devices available.
     */
    @Published public private(set) var devices: [String: OdinAudioDevice] = [:]

    /**
     * Initializes a new audio base instance and configures the internal `AVAudioEngine` instance.
     */
    private init() {
        self.engine = AVAudioEngine()
        
        self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: nil)
        
        self.registerNotificationHandlers()
        self.populateDevices()
    }
    
    /**
     * Destroys room and closes the connection to the server if needed.
     */
    deinit {
        self.stop()
    }
    
    /**
     * Starts the underlying `AVAudioEngine` instance.
     */
    public func start() throws {
        if !self.engine.isRunning {
            self.engine.prepare()
            
            try self.engine.start()
        }
    }
    
    /**
     * Stops the underlying `AVAudioEngine` instance.
     */
    public func stop() {
        if self.engine.isRunning {
            self.engine.stop()
        }
    }
    
    /**
     * Attaches the specified room to the underlying `AVAudioEngine` instance and connects it.
     */
    public func connect(_ room: OdinRoom) throws {
        guard !self.engine.attachedNodes.contains(room.audioNode) else {
            return
        }
        
        self.engine.attach(room.audioNode)
        self.engine.connect(room.audioNode, to: self.engine.mainMixerNode, format: nil)
        
        try self.start()
    }
    
    /**
     * Detaches the specified room from the underlying `AVAudioEngine` instance.
     */
    public func disconnect(_ room: OdinRoom) throws {
        guard self.engine.attachedNodes.contains(room.audioNode) else {
            return
        }
        
        self.engine.disconnectNodeOutput(room.audioNode)
        self.engine.detach(room.audioNode)
        
        try self.start()
    }

    /**
     * Attaches the specified media to the underlying `AVAudioEngine` instance and connects it.
     */
    public func connect(_ media: OdinMedia) throws {
        guard !self.engine.attachedNodes.contains(media.audioNode) else {
            return
        }
        
        guard media.id > 0 else {
            return
        }

        self.engine.attach(media.audioNode)
        
        if media.remote {
            self.engine.connect(media.audioNode, to: self.engine.mainMixerNode, format: nil)
        } else {
            self.stop()
            
            self.engine.connect(self.engine.inputNode, to: media.audioNode, format: nil)
        }
        
        try self.start()
    }
    
    /**
     * Detaches the specified media from the underlying `AVAudioEngine` instance.
     */
    public func disconnect(_ media: OdinMedia) throws {
        guard self.engine.attachedNodes.contains(media.audioNode) else {
            return
        }
        
        if media.remote {
            self.engine.disconnectNodeOutput(media.audioNode)
            self.engine.detach(media.audioNode)
        } else {
            self.stop()
            
            self.engine.disconnectNodeInput(self.engine.inputNode)
            self.engine.detach(media.audioNode)
        }
        
        try self.start()
    }
    
    /**
     * Populates the list of available.
     */
    private func populateDevices() {
        var devices: [String: OdinAudioDevice] = [:]
        
        for uid in self.getDeviceUids() {
            devices[uid] = OdinAudioDevice(uid)
        }
        
        self.devices = devices
    }
    
    /**
     * An list of audio input devices.
     */
    public var inputDevices: [String: OdinAudioDevice] {
        return self.devices.filter { device in
            device.value.isInput
        }
    }
    
    /**
     * An list of audio output devices.
     */
    public var outputDevices: [String: OdinAudioDevice] {
        return self.devices.filter { device in
            device.value.isOutput
        }
    }
    
    /**
     * Indicates the status of the underlying `AVAudioEngine` instance.
     */
    public var isRunning: Bool {
        return self.engine.isRunning
    }

    /**
     * Returns a shared instance of the audio engine.
     */
    public class func sharedInstance() -> OdinAudio {
        return self.shared
    }
}

/**
 * Notification extensions for `OdinAudio` class.
 */
extension OdinAudio {
    /**
     * Register notification handlers for the underlying `AVAudioEngine` instance.
     */
    private func registerNotificationHandlers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleConfigurationChange(_:)),
            name: .AVAudioEngineConfigurationChange,
            object: self.engine
        )
    }
    
    /**
     * Callback for `AVAudioEngineConfigurationChange` to restart the underlying `AVAudioEngine` if needed.
     */
    @objc func handleConfigurationChange(_ notification: Notification) {
        do {
            self.stop()
            try self.start()
        } catch {}
    }
}

/**
 * Device utlilty extensions for `OdinAudio` class.
 */
extension OdinAudio {
    /**
     * Returns a list of audio device UIDs available.
     */
    private func getDeviceUids() -> [String] {
#if os(macOS)
        let objectId = AudioObjectID(kAudioObjectSystemObject)
        
        guard let address = self.getPropertyAddress(objectId, selector: kAudioHardwarePropertyDevices) else {
            return []
        }
        
        var deviceIds = [AudioStreamID]()
        
        guard noErr == self.getPropertyDataArray(objectId, address: address, value: &deviceIds, defaultValue: 0) else {
            return []
        }
        
        var deviceUids = [String]()
        for deviceId in deviceIds {
            guard let address = self.getPropertyAddress(deviceId, selector: kAudioDevicePropertyDeviceUID) else {
                continue
            }
            
            var deviceUid: CFString?
            guard noErr == self.getPropertyData(deviceId, address: address, value: &deviceUid) else {
                continue
            }
            
            if deviceUid != nil {
                deviceUids.append(deviceUid! as NSString as String)
            }
        }
        
        return deviceUids
#else
        var devUids: [String] = []
        
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        
        for input in inputs {
            devUids.append(input.uid)
        }
        
        for output in outputs {
            devUids.append(output.uid)
        }
        
        return devUids
#endif
    }
    
    /**
     * Returns the total number of audio devices available.
     */
    private func getDeviceCount() -> UInt32 {
#if os(macOS)
        let objectId = AudioObjectID(kAudioObjectSystemObject)
        
        guard let address = self.getPropertyAddress(objectId, selector: kAudioHardwarePropertyDevices) else {
            return 0
        }
        
        var data: ExpressibleByNilLiteral?
        var size: UInt32 = 0
        
        guard noErr == self.getPropertyDataSize(objectId, address: address, dataSize: nil, data: &data, size: &size) else {
            return 0
        }
        
        return size / UInt32(MemoryLayout<AudioDeviceID>.size)
#else
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        
        return UInt32(inputs.count + outputs.count)
#endif
    }
}

/**
 * macOS specific extensions for `OdinAudio` class.
 */
#if os(macOS)
extension OdinAudio {
    /**
     * Returns a valid Core Audio object property address.
     */
    func getPropertyAddress(
        _ objectId: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMaster
    ) -> AudioObjectPropertyAddress? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        
        guard AudioObjectHasProperty(objectId, &address) else {
            return nil
        }
        
        return address
    }
    
    /**
     * Retrieves the data size of a Core Audio object property.
     */
    func getPropertyDataSize<Q>(
        _ objectId: AudioObjectID,
        address: AudioObjectPropertyAddress,
        dataSize: UInt32?,
        data: inout Q,
        size: inout UInt32
    ) -> OSStatus {
        var addr = address

        return AudioObjectGetPropertyDataSize(objectId, &addr, dataSize ?? UInt32(0), &data, &size)
    }
    
    /**
     * Retrieves the data of a Core Audio object property.
     */
    func getPropertyData<T>(
        _ objectId: AudioObjectID,
        address: AudioObjectPropertyAddress,
        value: inout T
    ) -> OSStatus {
        var addr = address
        var size = UInt32(MemoryLayout<T>.size)

        return AudioObjectGetPropertyData(objectId, &addr, UInt32(0), nil, &size, &value)
    }
    
    /**
     * Retrieves the data array of a Core Audio object property.
     */
    func getPropertyDataArray<T>(
        _ objectId: AudioObjectID,
        address: AudioObjectPropertyAddress,
        value: inout [T],
        defaultValue: T
    ) -> OSStatus {
        var addr = address
        var size = UInt32(0)
        var data: ExpressibleByNilLiteral?

        let result = self.getPropertyDataSize(
            objectId,
            address: address,
            dataSize: nil,
            data: &data,
            size: &size
        )

        if result == noErr {
            value = [T](repeating: defaultValue, count: Int(size) / MemoryLayout<T>.size)
        } else {
            return result
        }
        
        return AudioObjectGetPropertyData(objectId, &addr, UInt32(0), &data, &size, &value)
    }
}
#endif

/**
 * iOS specific extensions for `OdinAudio` class.
 */
#if os(iOS)
extension OdinAudio {
    func getPortByUid(_ uid: String) -> AVAudioSessionPortDescription? {
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        if let input = inputs.first(where: { $0.uid == uid }) {
            return input
        }
        
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        if let output = outputs.first(where: { $0.uid == uid }) {
            return output
        }
        
        return nil
    }
}
#endif
