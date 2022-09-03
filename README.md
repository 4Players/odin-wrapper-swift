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

#### OdinToken

ODIN generates signed JSON Web Tokens (JWT) for secure authentication, which contain the room(s) you want to join as well as a freely definable identifier for the user. The later can be used to refer to an existing record in your particular service. As ODIN is fully user agnostic, 4Players does not store any of this information on its servers.

#### OdinRoom

In ODIN, users who want to communicate with each other need to join the same room. Every `OdinRoom` instance allows setting an optional delegate to handle events. The delegate must be an instance of a class implementing the `OdinRoomDelegate` protocol, which defines all the necessary event callbacks. In addition, rooms have a set of observable properties using the `@Published` property wrapper. This allows you to easily monitor these variables as signals are emitted whenever their values were changed.

#### OdinPeer

Once a client joins a room, it will be treated as a peer. Every peer has its own user data, which is a byte array (`[UInt8]`). This data is synced automatically, which allows storing of arbitrary information for each individual peer and even globally for the room if needed. Peers can update their own user data at any time, even before joining a room to specify the initial user data value.

#### OdinMedia

Each peer in an ODIN room can attach media streams to transmit voice data. By default, ODIN will always assume that your input device is working with a sample rate of 48 kHz. If you need to change these settings, you can either specify a custom `OdinAudioStreamConfig` or attach the `OdinMedia` instances of your room to an existing `AVAudioEngine` instance of your app.

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