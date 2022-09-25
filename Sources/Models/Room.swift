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

import AVFAudio
import Foundation
import Odin

/**
 * Class to handle ODIN rooms.
 *
 * A room is the virtual space where clients can communicate with each other.
 */
public class OdinRoom: Hashable, ObservableObject {
    /**
     * The underlying room handle to interact with.
     */
    public internal(set) var roomHandle: OdinRoomHandle

    /**
     * An instance of your own peer in the room.
     */
    public let ownPeer: OdinPeer = .init()

    /**
     * The gateway URL used for authentication.
     */
    public private(set) var gateway: String = ""

    /**
     * Indicates how and if medias will be added to the capture/playback mix automatically.
     */
    public private(set) var audioAutopilot: OdinAudioAutopilotMode = .room

    /**
     * The underlying object that receives mixed audio data from remote medias in the room.
     */
    public internal(set) var audioNode: AVAudioSourceNode!

    /**
     * The audio processing module settings of the room.
     */
    public private(set) var audioConfig: OdinApmConfig = .init(
        voice_activity_detection: true,
        voice_activity_detection_attack_probability: 0.9,
        voice_activity_detection_release_probability: 0.8,
        volume_gate: false,
        volume_gate_attack_loudness: -30,
        volume_gate_release_loudness: -40,
        echo_canceller: false,
        high_pass_filter: false,
        pre_amplifier: false,
        noise_suppression_level: OdinNoiseSuppressionLevel_Moderate,
        transient_suppressor: false,
        gain_controller: false
    )

    /**
     * The name of the room.
     */
    @Published public private(set) var id: String = ""

    /**
     * The identifier of the customer the room is assigned to.
     */
    @Published public private(set) var customer: String = ""

    /**
     * A byte array with arbitrary user data attached to the room.
     */
    @Published public private(set) var userData: [UInt8] = []

    /**
     * A tuple with current connection status of the room including a reason identifier for the last update.
     */
    @Published public private(set) var connectionStatus = (
        state: OdinRoomConnectionState_Disconnected,
        reason: OdinRoomConnectionStateChangeReason_ClientRequested
    )

    /**
     * An array of current peers in the room.
     */
    @Published public private(set) var peers: [UInt64: OdinPeer] = [:]

    /**
     * An array of current medias in the room.
     */
    @Published public private(set) var medias: [OdinMediaStreamHandle: OdinMedia] = [:]

    /**
     * An optional delegate with custom event callbacks.
     */
    public weak var delegate: OdinRoomDelegate?

    /**
     * Initializes a new room instance.
     */
    public convenience init() {
        try! self.init(gateway: OdinGatewayUrl.production.rawValue)
    }

    /**
     * Initializes a new room instance using a custom gateway URL.
     */
    public init(gateway: String) throws {
        odin_startup(ODIN_VERSION)

        self.roomHandle = odin_room_create()

        try self.registerEventHandler()
        try self.updateGatewayUrl(gateway)
        try self.updateAudioConfig(self.audioConfig)

        self.audioNode = AVAudioSourceNode(
            format: OdinAudioConfig.format(),
            renderBlock: { [unowned self] _, _, frameCount, audioBufferList -> OSStatus in
                let buffer = UnsafeMutableBufferPointer<Float>(audioBufferList.pointee.mBuffers)
                var samples = Int(frameCount)

                do {
                    try self.mixMedias(buffer: buffer, frameCount: &samples, channelLayout: OdinChannelLayout_Mono)
                } catch {
                    return kAudioCodecIllegalOperationError
                }

                return noErr
            }
        )

        OdinManager.sharedInstance().registerRoom(self)
    }

    /**
     * Destroys the room handle and closes the connection to the server if needed.
     */
    deinit {
        if self.roomHandle != 0 {
            try? self.destroy()
        }

        odin_shutdown()

        OdinManager.sharedInstance().unregisterRoom(self)
    }

    /**
     * Destroys the underlying room handle.
     */
    func destroy() throws {
        let returnCode = odin_room_destroy(self.roomHandle)
        try OdinResult.validate(returnCode)

        self.roomHandle = 0
    }

    /**
     * Joins a room on an ODIN server and returns the ID of your own peer on success. This function takes a signed room
     * token obtained externally that authorizes the client to establish the connection.
     */
    public func join(token: String) throws -> UInt64 {
        return try self.join(token: OdinToken(token))
    }

    /**
     * Joins a room on an ODIN server and returns the ID of your own peer on success. This function takes a signed room
     * token obtained externally that authorizes the client to establish the connection.
     */
    public func join(token: OdinToken) throws -> UInt64 {
        self.id = (try? token.roomId) ?? ""
        self.ownPeer.userId = (try? token.userId) ?? ""

        let returnCode = odin_room_join(self.roomHandle, self.gateway, token.rawValue)
        try OdinResult.validate(returnCode)

        return self.ownPeer.id
    }

    /**
     * Leaves the room and closes the connection to the server if needed.
     */
    public func leave() throws {
        let returnCode = odin_room_close(self.roomHandle)
        try OdinResult.validate(returnCode)

        odin_room_destroy(self.roomHandle)

        self.roomHandle = odin_room_create()

        try self.registerEventHandler()
        try self.updateAudioConfig(self.audioConfig)
    }

    /**
     * Updates the settings of the audio processing module for the room. This includes everything from noise reduction
     * to smart voice activity detection.
     */
    public func updateAudioConfig(_ config: OdinApmConfig) throws {
        let returnCode = odin_room_configure_apm(self.roomHandle, config)
        try OdinResult.validate(returnCode)

        self.audioConfig = config
    }

    /**
     * Updates the gateway URL used for authentication.
     */
    public func updateGatewayUrl(_ gateway: String) throws {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        guard detector.firstMatch(in: gateway, options: [], range: NSRange(location: 0, length: gateway.utf16.count)) != nil else {
            throw OdinResult.error("failed to set gateway; url is invalid")
        }

        self.gateway = gateway
    }

    /**
     * Enables or disables the audio autopilot. This is a simple flag to control whether or not medias in the room will
     * be added to the default capture/playback mix automatically.
     */
    public func setAudioAutopilotMode(_ mode: OdinAudioAutopilotMode) throws {
        guard self.connectionStatus.state == OdinRoomConnectionState_Disconnected else {
            throw OdinResult.error("failed to set audio autopilot mode; room is in an invalid state")
        }

        self.audioAutopilot = mode
    }

    /**
     * Updates the custom user data for either your own peer or the specified room itself. This data is synced between
     * clients automatically, which allows storing of arbitrary information for each individual peer and even globally
     * for the room if needed.
     *
     * Note: Use this with target peer before calling `OdinRoom.join` to set initial peer user data upon connect.
     */
    public func updateUserData(userData: [UInt8], target: OdinUserDataTarget) throws {
        let returnCode = odin_room_update_user_data(self.roomHandle, target, userData, userData.count)
        try OdinResult.validate(returnCode)

        if target == OdinUserDataTarget_Peer {
            self.ownPeer.userData = userData

            if self.connectionStatus.state != OdinRoomConnectionState_Disconnected {
                self.delegate?.onPeerUserDataChanged(room: self, peer: self.ownPeer)
            }

            self.objectWillChange.send()
        } else {
            self.userData = userData

            if self.connectionStatus.state != OdinRoomConnectionState_Disconnected {
                self.delegate?.onRoomUserDataChanged(room: self)
            }
        }
    }

    /**
     * Updates the custom user data for your own peer. This data is synced between clients automatically.
     *
     * Note: Use this before calling `OdinRoom.join` to set initial peer user data upon connect.
     */
    public func updatePeerUserData(userData: [UInt8]) throws {
        try self.updateUserData(userData: userData, target: OdinUserDataTarget_Peer)
    }

    /**
     * Updates the custom user data for the current room. This data is synced between clients automatically.
     */
    public func updateRoomUserData(userData: [UInt8]) throws {
        try self.updateUserData(userData: userData, target: OdinUserDataTarget_Room)
    }

    /**
     * Updates the two-dimensional position of your own peer. The server will use the specified coordinates for each
     * peer in the same room to apply automatic culling based on unit circles with a radius of `1.0`. This is ideal for
     * any scenario, where you want to put a large numbers of peers into the same room and make them only 'see' each
     * other while being in proximity. Additionally, you can use `setPositionScale` to adjust the distance multiplier
     * for position updates if needed.
     *
     * Note: Use this before calling `OdinRoom.join` to set the initial peer position upon connect.
     */
    public func updatePosition(x: Float, y: Float) throws {
        let returnCode = odin_room_update_position(self.roomHandle, x, y)
        try OdinResult.validate(returnCode)
    }

    /**
     * Sets the scaling used for all coordinates passed to `updatePosition`. This allows adapting to the individual
     * needs of your game coorinate system if necessary. Only peers within a unit circle with a radius of `1.0` are
     * able to 'see' each other. When changing the position of a peer, the position must be scaled such as that the
     * maximum distance is one or less. The scaling can be done either manually or by setting the multiplicative scale
     * here.
     *
     * Note: Please make sure that all of your client apps use the same scaling.
     */
    public func setPositionScale(scale: Float) throws {
        let returnCode = odin_room_set_position_scale(self.roomHandle, scale)
        try OdinResult.validate(returnCode)
    }

    /**
     * Creates a new input stream of the specified type, adds it to the room and returns the media ID on success.
     */
    public func addMedia(type: OdinMediaStreamType) throws -> OdinMediaStreamHandle {
        switch type {
            case OdinMediaStreamType_Audio:
                let format = OdinAudioConfig.format()
                return try self.addMedia(audioConfig: OdinAudioStreamConfig(
                    sample_rate: UInt32(format.sampleRate),
                    channel_count: UInt8(format.channelCount)
                ))
            default:
                throw OdinResult.error("failed to create media stream; type is not implemented")
        }
    }

    /**
     * Creates new audio input stream using the specified config, adds it to the room and returns the media ID on
     * success. The new audio media can be used to transmit audio samples captured from a local microphone.
     */
    public func addMedia(audioConfig: OdinAudioStreamConfig) throws -> OdinMediaStreamHandle {
        let media = try OdinMedia(audioConfig)

        if self.localMedias.contains(where: { $0.value.type == OdinMediaStreamType_Audio }) {
            throw OdinResult.error("failed to add media stream; another audio stream is already started")
        }

        let returnCode = odin_room_add_media(self.roomHandle, media.streamHandle)
        try OdinResult.validate(returnCode)

        guard media.streamHandle != 0 else {
            throw OdinResult.error("failed to add media stream; handle is invalid")
        }

        self.medias.updateValue(media, forKey: media.streamHandle)
        self.ownPeer.medias.updateValue(media, forKey: media.streamHandle)

        if self.audioAutopilot != .off {
            try OdinAudio.sharedInstance().connect(media)
        }

        self.delegate?.onMediaAdded(room: self, peer: self.ownPeer, media: media)

        return media.streamHandle
    }

    /**
     * Removes the media instance matching the specified ID from the room and destroys it.
     */
    public func removeMedia(streamHandle: OdinMediaStreamHandle) throws {
        guard let media = self.medias[streamHandle] else {
            throw OdinResult.error("failed to remove media stream; handle is invalid")
        }

        try self.removeMedia(media: media)
    }

    /**
     * Removes the specified media instance from the room and destroys it.
     */
    public func removeMedia(media: OdinMedia) throws {
        let peerId = try media.peerId

        guard peerId == 0 else {
            throw OdinResult.error("failed to remove media stream; media is owned by remote peer")
        }

        self.medias.removeValue(forKey: media.streamHandle)
        self.ownPeer.medias.removeValue(forKey: media.streamHandle)

        if self.audioAutopilot != .off {
            try OdinAudio.sharedInstance().disconnect(media)
        }

        self.delegate?.onMediaRemoved(room: self, peer: self.ownPeer, media: media)
    }

    /**
     * Sends a message with arbitrary data to all other peers in the same room. Optionally, you can provide a list of
     * target IDs to send the message to specific peers only.
     */
    public func sendMessage(data: [UInt8], targetIds: [UInt64] = []) throws {
        let returnCode = odin_room_send_message(self.roomHandle, (targetIds.count != 0) ? targetIds : nil, targetIds.count, data, data.count)
        try OdinResult.validate(returnCode)
    }

    /**
     * Reads up to `frameCount` samples from the given streams and mixes them into the `buffer`. All audio streams will
     * be read based on a 48khz sample rate so make sure to allocate the buffer accordingly. After the call the `frameCount`
     * will contain the amount of samples that have actually been read and mixed into `buffer`.
     *
     * Note: If enabled this will also apply any audio processing to the output stream and feed back required data.
     */
    private func mixMedias(buffer: UnsafeMutableBufferPointer<Float>, frameCount: UnsafeMutablePointer<Int>, channelLayout: OdinChannelLayout) throws {
        let medias = self.remoteMedias.filter { media in
            media.value.audioNode.engine == nil
        }

        let returnCode = odin_audio_mix_streams(self.roomHandle, Array(medias.keys), self.remoteMedias.count, buffer.baseAddress, frameCount, channelLayout)
        try OdinResult.validate(returnCode)
    }

    /**
     * An array of current remote peers in the room.
     */
    public var remotePeers: [UInt64: OdinPeer] {
        return self.peers.filter { peer in
            peer.key != self.ownPeer.id
        }
    }

    /**
     * An array of current local medias in the room, which can be used for capture.
     */
    public var localMedias: [OdinMediaStreamHandle: OdinMedia] {
        return self.medias.filter { media in
            media.value.remote == false
        }
    }

    /**
     * An array of current remote medias in the room, which can be used for playback.
     */
    public var remoteMedias: [OdinMediaStreamHandle: OdinMedia] {
        return self.medias.filter { media in
            media.value.remote == true
        }
    }

    /**
     * Indicates wether or not the room handle is connected.
     */
    public var isConnected: Bool {
        return self.connectionStatus.state == OdinRoomConnectionState_Connected
    }

    /**
     * Indicates wether or not the room handle is connecting.
     */
    public var isConnecting: Bool {
        return self.connectionStatus.state == OdinRoomConnectionState_Connecting
    }

    /**
     * Indicates wether or not the room handle is disconnected.
     */
    public var isDisconnected: Bool {
        return self.connectionStatus.state == OdinRoomConnectionState_Disconnected
    }

    /**
     * Hashes the essential components of the room by feeding them into the given hasher.
     */
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /**
     * Returns a value indicating whether two type-erased hashable instances wrap the same room.
     */
    public static func ==(lhs: OdinRoom, rhs: OdinRoom) -> Bool {
        return lhs === rhs
    }
}

/**
 * Extensions for `OdinRoom` class.
 */
extension OdinRoom {
    /**
     * Generic callback to handle events from an ODIN room.
     */
    typealias EventCallback = @convention(c) (
        OdinRoomHandle,
        UnsafePointer<OdinEvent>?,
        UnsafeMutableRawPointer?
    ) -> Void

    /**
     * Register callback handler for ODIN room events.
     */
    private func registerEventHandler() throws {
        let callback: EventCallback = {
            _, event, extraData in
            if let event = event, let extraData = extraData {
                unsafeBitCast(extraData, to: OdinRoom.self).handleEvent(event: event)
            }
        }

        let returnCode = odin_room_set_event_callback(self.roomHandle, callback, Unmanaged.passUnretained(self).toOpaque())
        try OdinResult.validate(returnCode)
    }

    /**
     * Unregister callback handler for ODIN room events.
     */
    private func unregisterEventHandler() throws {
        let returnCode = odin_room_set_event_callback(self.roomHandle, nil, nil)
        try OdinResult.validate(returnCode)
    }

    /**
     * Handles events emitted in this ODIN room.
     */
    private func handleEvent(event: UnsafePointer<Odin.OdinEvent>) {
        switch event.pointee.tag {
            case OdinEvent_RoomConnectionStateChanged:
                self.handleRoomConnectionStateChangedEvent(data: event.pointee.room_connection_state_changed)
            case OdinEvent_RoomUserDataChanged:
                self.handleRoomUserDataChangedEvent(data: event.pointee.room_user_data_changed)
            case OdinEvent_Joined:
                self.handleJoinedEvent(data: event.pointee.joined)
            case OdinEvent_PeerJoined:
                self.handlePeerJoinedEvent(data: event.pointee.peer_joined)
            case OdinEvent_PeerUserDataChanged:
                self.handlePeerUserDataChangedEvent(data: event.pointee.peer_user_data_changed)
            case OdinEvent_PeerLeft:
                self.handlePeerLeftEvent(data: event.pointee.peer_left)
            case OdinEvent_MediaAdded:
                self.handleMediaAddedEvent(data: event.pointee.media_added)
            case OdinEvent_MediaActiveStateChanged:
                self.handleMediaActiveStateChangedEvent(data: event.pointee.media_active_state_changed)
            case OdinEvent_MediaRemoved:
                self.handleMediaRemovedEvent(data: event.pointee.media_removed)
            case OdinEvent_MessageReceived:
                self.handleMessageReceivedEvent(data: event.pointee.message_received)
            default:
                break
        }
    }

    /**
     * Handles `OdinEvent_RoomConnectionStateChanged` events emitted whenever the internal connectivity state of the
     * room was updated.
     */
    private func handleRoomConnectionStateChangedEvent(data: OdinEvent_RoomConnectionStateChangedData) {
        let oldState = self.connectionStatus.state
        let newState = OdinRoomConnectionState(rawValue: data.state.rawValue)
        let reason = OdinRoomConnectionStateChangeReason(rawValue: data.reason.rawValue)

        DispatchQueue.main.async {
            self.connectionStatus = (
                state: newState,
                reason: reason
            )

            if self.connectionStatus.state == OdinRoomConnectionState_Connected {
                if self.audioAutopilot == .room {
                    try? OdinAudio.sharedInstance().connect(self)
                }
            } else if self.connectionStatus.state == OdinRoomConnectionState_Disconnected {
                if self.audioAutopilot == .room {
                    try? OdinAudio.sharedInstance().disconnect(self)
                }

                self.medias.removeAll()
                self.peers.removeAll()

                self.id = ""
                self.customer = ""
                self.userData = []
                self.ownPeer.id = 0
            }

            if self.delegate != nil {
                self.delegate?.onRoomConnectionStateChanged(room: self, oldState: oldState, newState: newState, reason: reason)
            }
        }
    }

    /**
     * Handles `OdinEvent_RoomUserDataChanged` events emitted whenever the user data of the room was updated.
     */
    private func handleRoomUserDataChangedEvent(data: OdinEvent_RoomUserDataChangedData) {
        let roomUserData = [UInt8](UnsafeBufferPointer(
            start: data.room_user_data,
            count: data.room_user_data_len
        ))

        DispatchQueue.main.async {
            self.userData = roomUserData

            if self.delegate != nil {
                self.delegate?.onRoomUserDataChanged(room: self)
            }
        }
    }

    /**
     * Handles `OdinEvent_Joined` events emitted when the room was joined successfully.
     */
    private func handleJoinedEvent(data: OdinEvent_JoinedData) {
        let roomId = String(cString: data.room_id)
        let customer = String(cString: data.customer)
        let roomUserData = [UInt8](UnsafeBufferPointer(
            start: data.room_user_data,
            count: data.room_user_data_len
        ))

        DispatchQueue.main.async {
            self.id = roomId
            self.customer = customer
            self.userData = roomUserData
            self.ownPeer.id = data.own_peer_id

            self.peers.updateValue(self.ownPeer, forKey: data.own_peer_id)

            if self.delegate != nil {
                self.delegate?.onPeerJoined(room: self, peer: self.ownPeer)
                self.delegate?.onRoomJoined(room: self)
            }
        }
    }

    /**
     * Handles `OdinEvent_PeerJoined` events emitted whenever a remote peer joined the room.
     */
    private func handlePeerJoinedEvent(data: OdinEvent_PeerJoinedData) {
        let peer = OdinPeer(
            id: data.peer_id,
            userId: String(cString: data.user_id),
            userData: [UInt8](UnsafeBufferPointer(start: data.peer_user_data, count: data.peer_user_data_len))
        )

        DispatchQueue.main.async {
            self.peers.updateValue(peer, forKey: data.peer_id)

            if self.delegate != nil {
                self.delegate?.onPeerJoined(room: self, peer: peer)
            }
        }
    }

    /**
     * Handles `OdinEvent_PeerUserDataChanged` events emitted whenever the user data of a peer in the room was updated.
     */
    private func handlePeerUserDataChangedEvent(data: OdinEvent_PeerUserDataChangedData) {
        let peerId = data.peer_id
        let peerUserData = [UInt8](UnsafeBufferPointer(
            start: data.peer_user_data,
            count: data.peer_user_data_len
        ))

        DispatchQueue.main.async {
            guard let peer = self.peers[peerId] else {
                return
            }

            peer.userData = peerUserData

            if self.delegate != nil {
                self.delegate?.onPeerUserDataChanged(room: self, peer: peer)
            }

            self.objectWillChange.send()
        }
    }

    /**
     * Handles `OdinEvent_PeerLeft` events emitted whenever a remote peer left the room.
     */
    private func handlePeerLeftEvent(data: OdinEvent_PeerLeftData) {
        let peerId = data.peer_id

        DispatchQueue.main.async {
            guard let peer = self.peers[peerId] else {
                return
            }

            self.peers.removeValue(forKey: peerId)

            if self.delegate != nil {
                self.delegate?.onPeerLeft(room: self, peer: peer)
            }
        }
    }

    /**
     * Handles `OdinEvent_MediaAdded` events emitted whenever a media stream was added to the room.
     */
    private func handleMediaAddedEvent(data: OdinEvent_MediaAddedData) {
        let peerId = data.peer_id
        let handle = data.media_handle

        guard let media = try? OdinMedia(handle) else {
            return
        }

        DispatchQueue.main.async {
            guard let peer = self.peers[peerId] else {
                return
            }

            self.medias.updateValue(media, forKey: handle)
            peer.medias.updateValue(media, forKey: handle)

            if self.audioAutopilot == .room {
                try? OdinAudio.sharedInstance().connect(media)
            }

            if self.delegate != nil {
                self.delegate?.onMediaAdded(room: self, peer: peer, media: media)
            }
        }
    }

    /**
     * Handles `OdinEvent_MediaActiveStateChanged` events emitted whenever a media stream in the room started/stopped
     * sending/receiving data (e.g. when a user started/stopped talking).
     */
    private func handleMediaActiveStateChangedEvent(data: OdinEvent_MediaActiveStateChangedData) {
        let peerId = data.peer_id
        let handle = data.media_handle
        let active = data.active

        DispatchQueue.main.async {
            guard let peer = self.peers[peerId], let media = self.medias[handle] else {
                return
            }

            media.activityStatus = active

            if self.delegate != nil {
                self.delegate?.onMediaActiveStateChanged(room: self, peer: peer, media: media)
            }

            self.objectWillChange.send()
        }
    }

    /**
     * Handles `OdinEvent_MediaRemoved` events emitted whenever a media stream was removed from the room.
     */
    private func handleMediaRemovedEvent(data: OdinEvent_MediaRemovedData) {
        let peerId = data.peer_id
        let handle = data.media_handle

        DispatchQueue.main.async {
            guard let peer = self.peers[peerId], let media = self.medias[handle] else {
                return
            }

            if self.audioAutopilot == .room {
                try? OdinAudio.sharedInstance().disconnect(media)
            }

            self.medias.removeValue(forKey: handle)
            peer.medias.removeValue(forKey: handle)

            if self.delegate != nil {
                self.delegate?.onMediaRemoved(room: self, peer: peer, media: media)
            }
        }
    }

    /**
     * Handles `OdinEvent_MessageReceived` events emitted whenever a message with arbitrary data was received in the
     * room. Note, that the sender peer ID is not necessarily in the list of known peers as it might be out of range.
     */
    private func handleMessageReceivedEvent(data: OdinEvent_MessageReceivedData) {
        let message = [UInt8](UnsafeBufferPointer(
            start: data.data,
            count: data.data_len
        ))

        DispatchQueue.main.async {
            if self.delegate != nil {
                self.delegate?.onMessageReceived(room: self, senderId: data.peer_id, data: message)
            }
        }
    }
}
