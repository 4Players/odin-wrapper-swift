//: # 4Players ODIN
//:
//: OdinKit is a Swift package providing an object-oriented wrapper for the ODIN native client library. This playground
//: shows how to use ODIN in your **macOS** apps, but the same code will also work on **iOS** and **iPadOS**.
//:
//: ----
//:
//: ## Getting Started
//:
//: To start using ODIN in your Swift project, you need to import the `OdinKit` package. This will provide access to
//: just everything you need including low-level access to C-API functions.

import OdinKit

//: ## Working with Rooms
//:
//: In ODIN, users who want to communicate with each other need to join the same **room**.
//:
//: Optionally, you can specify an alternative gateway URL when initializing an `OdinRoom` instance. With ODIN, you
//: can choose between a managed cloud and a self-hosted solution. Let 4Players deal with the setup, administration
//: and bandwidth costs or run our server software on your own infrastructure allowing you complete control and
//: customization of your deployment environment. Unless you're hosting your own servers, you don't need to set a
//: gateway URL, which will make the ODIN client use the default gateway running at `https://gateway.odin.4players.io`.

// Create a new room instance
let room = OdinRoom(gateway: "https://gateway.odin.4players.io")

//: ## Handing Events
//:
//: The ODIN API is event driven. Using the `OdinKit` package, you have two ways of handing events emitted in an ODIN
//: room:
//:
//: ### 1) Setting a Room Delegate
//:
//: Every `OdinRoom` instance allows setting an optional delegate to handle events. The delegate must be an instance of
//: a class implementing the `OdinRoomDelegate` protocol, which defines all the necessary event callbacks.

// Define a class handing events
class YourCustomDelegate: OdinRoomDelegate {
    // Callback for internal room connectivity state changes
    func onRoomConnectionStateChanged(room: OdinRoom, oldState: OdinRoomConnectionState, newState: OdinRoomConnectionState, reason: OdinRoomConnectionStateChangeReason) {
        print("Connection status changed from \(oldState.rawValue) to \(newState.rawValue)")
    }

    // Callback for when a room was joined and the initial state is fully available
    func onRoomJoined(room: OdinRoom) {
        print("Room joined successfully as peer \(room.ownPeer.id)")
    }

    // Callback for room user data changes
    func onRoomUserDataChanged(room: OdinRoom) {
        print("Global room user data changed to: \(room.userData)")
    }

    // Callback for peers joining the room
    func onPeerJoined(room: OdinRoom, peer: OdinPeer) {
        print("Peer \(peer.id) joined the room with ID '\(peer.userId)'")
    }

    // Callback for peer user data changes
    func onPeerUserDataChanged(room: OdinRoom, peer: OdinPeer) {
        print("Peer \(peer.id) updated its user data to: \(peer.userData)")
    }

    // Callback for peers leaving the room
    func onPeerLeft(room: OdinRoom, peer: OdinPeer) {
        print("Peer \(peer.id) left the room")
    }

    // Callback for medias being added to the room
    func onMediaAdded(room: OdinRoom, peer: OdinPeer, media: OdinMedia) {
        print("Peer \(peer.id) added media \(media.id) to the room")
    }

    // Callback for media activity state changes
    func onMediaActiveStateChanged(room: OdinRoom, peer: OdinPeer, media: OdinMedia) {
        print("Peer \(peer.id) \(media.activityStatus ? "started" : "stopped") talking on media \(media.id)")
    }

    // Callback for medias being removed from the room
    func onMediaRemoved(room: OdinRoom, peer: OdinPeer, media: OdinMedia) {
        print("Peer \(peer.id) removed media \(media.id) from the room")
    }

    // Callback for incoming arbitrary data messages
    func onMessageReceived(room: OdinRoom, senderId: UInt64, data: [UInt8]) {
        print("Peer \(senderId) sent a message with arbitrary data: \(data)")
    }
}

// Create an instance of your delegate
let delegate = YourCustomDelegate()

// Add the delegate to the room
room.delegate = delegate

//: ### 2) Using Published Properties
//:
//: Every `OdinRoom` instance provides a set of observable properties using the `@Published` property wrapper. This
//: allows you to easily monitor these variables as signals are emitted whenever their values were changed.
//:
//: There are three distinct properties you can observe:
//:
//: * `OdinRoom.connectionStatus` \
//:     This is a tuple representing current connection status of the room including a reason identifier for the last
//:     update.
//: * `OdinRoom.peers` \
//:     This is a dictionary containing all peers in the room, indexed by their ID. Each peer has its own `userData`
//:     property, which is also observable and stores a byte array with arbitrary data assigned by the user.
//: * `OdinRoom.medias` \
//:     This is a dictionary containing all locel and remote media streams in the room, indexed by their ID. Each media
//:     has an observable property called `activityStatus`, which indicates wether or not the media stream is sending
//:     or receiving data.

// Monitor the room connection status
room.$connectionStatus.sink {
    print("New Connection Status: \($0.state.rawValue)")
}

// Monitor the list of peers in the room
room.$peers.sink {
    print("New Peers: \($0.keys)")
}

// Monitor the list of media streams in the room
room.$medias.sink {
    print("New Medias: \($0.keys)")
}

//: ## Obtaining an Authentication Token
//:
//: To enter (join) a room, clients need a token obtained externally to authenticate. For demonstration purposes, we
//: will generating a token using a local **access key**.
//:
//: An access key is the unique authentication key to be used to generate room tokens for accessing the ODIN server
//: network. You should think of it as your individual username and password combination all wrapped up into a single
//: non-comprehendible string of characters, and treat it with the same respect. For your own security, we strongly
//: recommend that you **NEVER** put an access key in your client-side code. We've created a very basic Node.js server
//: [here](https://developers.4players.io/odin/examples/token-server/), to showcase how to issue ODIN tokens to your
//: client apps without exposing your access key.
//:
//: ODIN generates signed JSON Web Tokens (JWT) for secure authentication, which contain the room(s) you want to join
//: as well as a freely definable identifier for the user. The later can be used to refer to an existing record in your
//: particular service. As ODIN is fully user agnostic, 4Players does not store any of this information on its servers.
//:
//: To create a token locally, simply spawn an `OdinAccessKey` instance using your access key string like this:
//:
//: ```
//: do {
//:     let yourAccessKey = try OdinAccessKey("YOUR_ACCESS_KEY")
//: } catch {
//:     print("Something went wrong, \(error)")
//: }
//: ```
//:
//: **Note:** Using the `OdinAccessKey` default initializer will always create a new access key.

// Create a new local access key
let accessKey = OdinAccessKey()

// Print the access key
print("Using access key \(accessKey.rawValue)")

// Generate a token to authenticate with
let authToken = try accessKey.generateToken(roomId: "Meeting Room", userId: "Swift is great!")

//: ## Joining a Room
//:
//: After obtaining a token for authentication, we can join the room. Once a client joins a room, it will be treated as
//: a **peer** and we can access our own information using the `ownPeer` property.

// Now that we have a token, join the room
try room.join(token: authToken)

//: ## Setting User Data
//:
//: Every peer has its own user data, which is a byte array (`[UInt8]`). This data is synced automatically, which allows
//: storing of arbitrary information for each individual peer and even globally for the room if needed. Peers can update
//: their own user data at any time, even before joining a room to specify the initial user data value. For convenience,
//: we're providing a set of helper functions in `OdinCustomData` to handle user data conversion:
//:
//: ### 1) Using a String
//:
//: Use `encode` and `decode` to convert from `String` to `[UInt8]` and vice versa.

// Define a string we want to set as our peer user data
let yourString = "Hello World!"

// Convert the string to a byte array
let stringData = OdinCustomData.encode(yourString)

// Set the user data
try room.updateUserData(userData: stringData, target: OdinUserDataTarget_Peer)

//: ### 2) Using a Custom Type
//:
//: Use `encode` and `decode` to convert from types implementing the `Codable` protocol to `[UInt8]` and
//: vice versa.

// Define a codable type
struct YourCustomData: Codable {
    var name: String
}

// Initialize the new type
let yourCodable = YourCustomData(name: "John Doe")

// Convert the type to a byte array
let codableData = OdinCustomData.encode(yourCodable)

// Set the user data
try room.updateUserData(userData: codableData, target: OdinUserDataTarget_Peer)

//: ## Sending Messages
//:
//: ODIN allows you to send arbitrary to every other peer in the room or even individual targets. Just like user data, a
//: message is a byte array (`[UInt8]`), which means that you can use the same convenience functions in `OdinCustomData`
//: to make your life easier.
//:
//: To send a message to a list of individual peers, simply specify a lif of peer IDs for the `targetIds` argument. We can
//: even send messages to ourselves by explicitly adding our own peer ID to the list.
//:
//: ```
//: do {
//:     try room.sendMessage(data: byteArray, targetIds: [1, 2, 3, 4])
//: } catch {
//:     print("Something went wrong, \(error)")
//: }
//: ```
//:
//: **Note:** Messages are always sent to all targets in the room, even when they moved out of proximity using `setPosition`.

// Encode a string so we can send it as a message
let yourMessage = OdinCustomData.encode("So Long, and Thanks for All the Fish")

// Send the message everyone else in the room
try room.sendMessage(data: yourMessage)

//: ## Audio Processing
//:
//: Each ODIN room handle has its own audio processing module (APM), which is in charge of filters like echo cancellation,
//: noise suppression, advanced voice activity detection and more. These settings can be changed on-the-fly by passing an
//: `OdinApmConfig` to the rooms `updateAudioConfig`.
//:
//: The ODIN APM provides the following features:
//:
//: ### Voice Activity Detection (VAD)
//:
//: When enabled, ODIN will analyze the audio input signal using smart voice detection algorithm to determine the presence
//: of speech. You can define both the probability required to start and stop transmitting.
//:
//: ### Input Volume Gate
//:
//: When enabled, the volume gate will measure the volume of the input audio signal, thus deciding when a user is speaking
//: loud enough to transmit voice data. You can define both the root mean square power (dBFS) for when the gate should engage
//: and disengage.
//:
//: ### Acoustic Echo Cancellation (AEC)
//:
//: When enabled the echo canceller will try to subtract echoes, reverberation, and unwanted added sounds from the audio input
//: signal. Note, that you need to processes the reverse audio stream, also known as the loopback data to be used in the ODIN
//: echo canceller.
//:
//: ### Noise Suppression
//:
//: When enbabled, the noise suppressor will remove distracting background noise from the input audio signal. You can control
//: the aggressiveness of the suppression. Increasing the level will reduce the noise level at the expense of a higher speech
//: distortion.
//:
//: ### High-Pass Filter (HPF)
//:
//: When enabled, the high-pass filter will remove low-frequency content from the input audio signal, thus making it sound
//: cleaner and more focused.
//:
//: ### Preamplifier
//:
//: When enabled, the preamplifier will boost the signal of sensitive microphones by taking really weak audio signals and
//: making them louder.
//:
//: ### Transient Suppression
//:
//: When enabled, the transient suppressor will try to detect and attenuate keyboard clicks.

// Create a new APM settings struct
let audioConfig: OdinApmConfig = .init(
    voice_activity_detection: true,
    voice_activity_detection_attack_probability: 0.9,
    voice_activity_detection_release_probability: 0.8,
    volume_gate: true,
    volume_gate_attack_loudness: -30,
    volume_gate_release_loudness: -40,
    echo_canceller: true,
    high_pass_filter: true,
    pre_amplifier: true,
    noise_suppression_level: OdinNoiseSuppressionLevel_Moderate,
    transient_suppressor: true
)

// Update the APM settings of the room
try room.updateAudioConfig(audioConfig)

//: ## Working with Media Streams
//:
//: Each peer in an ODIN room can attach media streams to transmit voice data. By default, ODIN will always assume that
//: your input device is working with a sample rate of 48 kHz. If you need to change these settings, you can either specify
//: a custom `audioConfig` or attach the `OdinMedia` instances of your `OdinRoom` to an existing `AVAudioEngine` instance
//: of your app.
//:
//: To use a different sample rate or channel count, you can pass a custom `OdinAudioStreamConfig` like this:
//:
//: ```
//: do {
//:     let newMediaId = try room.addMedia(audioConfig: OdinAudioStreamConfig(
//:         sample_rate: 48000,
//:         channel_count: 1
//:     ))
//: } catch {
//:     print("Something went wrong, \(error)")
//: }
//: ```
//:
//: Please refer to our [online documentation](https://www.4players.io/developers) for details.

// Append a local audio stream to capture our microphone
try room.addMedia(type: OdinMediaStreamType_Audio)
