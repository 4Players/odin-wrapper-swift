![OdinKit](https://www.4players.io/images/odin/banner.jpg)

[![Releases](https://img.shields.io/github/release/4Players/odin-wrapper-swift)](https://github.com/4Players/odin-wrapper-swift/releases)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20iOS-lightgrey)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/4Players/odin-wrapper-swift/blob/master/LICENSE)
[![Documentation](https://img.shields.io/badge/docs-4Players.io-orange)](https://www.4players.io/developers/)
[![Twitter](https://img.shields.io/badge/twitter-@4PlayersBiz-blue)](https://twitter.com/4PlayersBiz)

# OdinKit

OdinKit is a Swift package providing an object-oriented wrapper for the [ODIN](https://github.com/4Players/odin-sdk) native client library, which enables developers to integrate real-time VoIP chat technology into multiplayer games and apps on macOS and iOS.

## Requirements

- iOS 9.0+ / macOS 10.15+
- Xcode 10.2+
- Swift 5.0+

### ODIN XCFramework

To use OdinKit, you'll need the `Odin.xcframework` bundle in the `Frameworks` directory. We'll provide builds with matching XCFrameworks for each version on the [GitHub Releases](https://github.com/4Players/odin-wrapper-swift/releases) page.

An XCFramework is a distributable binary package created by Xcode, which contains variants of a framework or library so that it can be used on multiple platforms. In case of ODIN, the XCFramework contains relevant C header files and a set of static libraries for the following platforms:

| Platform | x86_64             | aarch64            |
| -------- | ------------------ | ------------------ |
| macOS    | :white_check_mark: | :white_check_mark: |
| iOS      | :white_check_mark: | :white_check_mark: |

To manually add the correct XCFramework version, please refer to `Sources/OdinKit.swift` for the required version number and download the `odin-xcframework.tgz` file from the appropriate release of the [ODIN Core SDK](https://github.com/4Players/odin-sdk/releases).

## Usage

### Quick Start

The following code snippet will create a token for authentication, join a room called _"Meeting Room"_ and add a media stream using your default audio input device:

```swift
import OdinKit

let room = OdinRoom()

do {
    let accessKey = try OdinAccessKey("<YOUR_ACCESS_KEY>")
    let authToken = try accessKey.generateToken(roomId: "Meeting Room")

    try room.join(token: authToken)
    try room.addMedia(type: OdinMediaStreamType_Audio)
} catch {
    print("Something went wrong, \(error)")
}
```

### Playground

This project contains a macOS [playground](https://github.com/4Players/odin-wrapper-swift/blob/master/Playgrounds/macOS.playground/Contents.swift) to demonstrate how to use OdinKit in your your apps, but the same code will also work on iOS and iPadOS.

### Class Overview

OdinKit provides a set of classes to provide easy access to just everything you need including low-level access to C-API functions of the [ODIN Core SDK](https://github.com/4Players/odin-sdk/blob/master/include/odin.h).

#### OdinAccessKey

An access key is the unique authentication key to be used to generate room tokens for accessing the ODIN server network. You should think of it as your individual username and password combination all wrapped up into a single non-comprehendible string of characters, and treat it with the same respect. For your own security, we strongly recommend that you **NEVER** put an access key in your client-side code. We've created a very basic Node.js server [here](https://developers.4players.io/odin/examples/token-server/), to showcase how to issue ODIN tokens to your client apps without exposing your access key.

**Note:** Using the `OdinAccessKey` default initializer will always create a new access key.

```swift
// Create a new access key
let accessKey = OdinAccessKey()

// Print information about the access key
print("Public Key: \(accessKey.publicKey)")
print("Secret Key: \(accessKey.secretKey)")
print("Key ID:     \(accessKey.id)")
```

#### OdinToken

ODIN generates signed JSON Web Tokens (JWT) for secure authentication, which contain the room(s) you want to join as well as a freely definable identifier for the user. The later can be used to refer to an existing record in your particular service.

As ODIN is fully user agnostic, [4Players GmbH](https://www.4players.io) does not store any of this information on its servers.

```swift
// Generate a token to authenticate with
let authToken = try accessKey.generateToken(roomId: "foo", userId: "bar")
```

#### OdinRoom

In ODIN, users who want to communicate with each other need to join the same room. Optionally, you can specify an alternative gateway URL when initializing an `OdinRoom` instance.

You can choose between a managed cloud and a self-hosted solution. Let [4Players GmbH](https://www.4players.io) deal with the setup, administration and bandwidth costs or run our server software on your own infrastructure allowing you complete control and customization of your deployment environment. Unless you're hosting your own servers, you don't need to set a gateway URL, which will make the ODIN client use the default gateway running in the European Union.

```swift
// Create a new room instance
let room = OdinRoom(gateway: "https://gateway.odin.4players.io")

// Join the room
let ownPeerId = try room.join(token: authToken)

// Print information about the room
print("ID:        \(room.id)")
print("User Data: \(room.userData)")
```

#### OdinPeer

Once a client joins a room, it will be treated as a peer. Every peer has its own user data, which is a byte array (`[UInt8]`). This data is synced automatically, which allows storing of arbitrary information for each individual peer and even globally for the room if needed.

Peers can update their own user data at any time, even before joining a room to specify the initial user data value.

```swift
// Print information for all peers in the room
for (peerId, peer) in room.peers {
    print("ID:        \(peer.id)")
    print("User ID:   \(peer.userId)")
    print("User Data: \(peer.userData)")
    print("Is Self:   \(peer == room.ownPeer)")
}
```

#### OdinMedia

Each peer in an ODIN room can attach media streams to transmit voice data. By default, ODIN will always assume that your input device is working with a sample rate of 48 kHz. If you need to change these settings, you can either specify a custom `OdinAudioStreamConfig` or attach the `OdinMedia` instances of your room to an existing `AVAudioEngine` instance of your app.

```swift
// Append a local audio stream to capture our microphone
let newMediaId = try room.addMedia(audioConfig: OdinAudioStreamConfig(
    sample_rate: 48000,
    channel_count: 1
))
```

### Event Handling

The ODIN API is event driven. Using the OdinKit package, you have two ways of handing events emitted in an ODIN room:

#### a) Setting a Room Delegate

Every `OdinRoom` instance allows setting an optional delegate to handle events. The delegate must be an instance of a class implementing the `OdinRoomDelegate` protocol, which defines all the necessary event callbacks.

```swift
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
```

#### b) Using Published Properties

Every `OdinRoom` instance provides a set of observable properties using the `@Published` property wrapper. This allows you to easily monitor these variables as signals are emitted whenever their values were changed.

There are three distinct properties you can observe:

- `OdinRoom.connectionStatus` \
This is a tuple representing current connection status of the room including a reason identifier for the last update.
- `OdinRoom.peers` \
This is a dictionary containing all peers in the room, indexed by their ID. Each peer has its own `userData` property, which is also observable and stores a byte array with arbitrary data assigned by the user.
- `OdinRoom.medias` \
This is a dictionary containing all local and remote media streams in the room, indexed by their stream handle. Each media has an observable property called `activityStatus`, which indicates wether or not the media stream is sending or receiving data.

```swift
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
```

### Audio Processing

Each ODIN room handle has its own audio processing module (APM), which is in charge of filters like echo cancellation, noise suppression, advanced voice activity detection and more. These settings can be changed on-the-fly by passing an OdinApmConfig to the rooms updateAudioConfig.

The ODIN APM provides the following features:

#### Voice Activity Detection (VAD)

When enabled, ODIN will analyze the audio input signal using smart voice detection algorithm to determine the presence of speech. You can define both the probability required to start and stop transmitting.

#### Input Volume Gate

When enabled, the volume gate will measure the volume of the input audio signal, thus deciding when a user is speaking loud enough to transmit voice data. You can define both the root mean square power (dBFS) for when the gate should engage and disengage.

#### Acoustic Echo Cancellation (AEC)

When enabled the echo canceller will try to subtract echoes, reverberation, and unwanted added sounds from the audio input signal. Note, that you need to process the reverse audio stream, also known as the loopback data to be used in the ODIN echo canceller.

#### Noise Suppression

When enbabled, the noise suppressor will remove distracting background noise from the input audio signal. You can control the aggressiveness of the suppression. Increasing the level will reduce the noise level at the expense of a higher speech distortion.

#### High-Pass Filter (HPF)

When enabled, the high-pass filter will remove low-frequency content from the input audio signal, thus making it sound cleaner and more focused.

#### Preamplifier

When enabled, the preamplifier will boost the signal of sensitive microphones by taking really weak audio signals and making them louder.

#### Transient Suppression

When enabled, the transient suppressor will try to detect and attenuate keyboard clicks.

```swift
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
```

### User Data

Every peer has its own user data, which is a byte array (`[UInt8]`). This data is synced automatically, which allows storing of arbitrary information for each individual peer and even globally for the room if needed. Peers can update their own user data at any time, even before joining a room to specify the initial user data value. For convenience, we're providing a set of helper functions in `OdinCustomData` to handle user data conversion:

#### a) Using a String

Use `encode` and `decode` to convert from `String` to `[UInt8]` and vice versa.

```swift
// Define a string we want to set as our peer user data
let yourString = "Hello World!"

// Convert the string to a byte array
let stringData = OdinCustomData.encode(yourString)

// Set the user data
try room.updateUserData(userData: stringData, target: OdinUserDataTarget_Peer)
```

#### b) Using a Custom Type

Use `encode` and `decode` to convert from types implementing the `Codable` protocol to `[UInt8]` and vice versa.

```swift
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
```

#### Messages

ODIN allows you to send arbitrary to every other peer in the room or even individual targets. Just like user data, a message is a byte array (`[UInt8]`), which means that you can use the same convenience functions in `OdinCustomData` to make your life easier.

To send a message to a list of individual peers, simply specify a lif of peer IDs for the `targetIds` argument. We can even send messages to ourselves by explicitly adding our own peer ID to the list.

**Note:** Messages are always sent to all targets in the room, even when they moved out of proximity using setPosition.

```swift
// Encode a string so we can send it as a message
let yourMessage = OdinCustomData.encode("So Long, and Thanks for All the Fish")

// Send the message everyone else in the room
try room.sendMessage(data: yourMessage)
```

## Resources

- [Documentation](https://www.4players.io/developers/)
- [Examples](https://www.4players.io/odin/examples/)
- [Frequently Asked Questions](https://www.4players.io/odin/faq/)
- [Pricing](https://www.4players.io/odin/pricing/)

## License

OdinKit is released under the MIT license. See [LICENSE](https://github.com/4Players/odin-wrapper-swift/blob/master/LICENSE) for details.

## Troubleshooting

Contact us through the listed methods below to receive answers to your questions and learn more about ODIN.

### Discord

Join our official Discord server to chat with us directly and become a part of the 4Players ODIN community.

[![Join us on Discord](https://developers.4players.io/images/join_discord.png)](https://discord.gg/9yzdJNUGZS)

### Twitter

Have a quick question? Tweet us at [@4PlayersBiz](https://twitter.com/4PlayersBiz) and we’ll help you resolve any issues.

### Email

Don’t use Discord or Twitter? Send us an [email](mailto:odin@4players.io) and we’ll get back to you as soon as possible.