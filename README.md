# Robin: iOS Audio Player

Welcome to Robin, the open-source audio player for iOS, developed by the team at The Guardian. Robin aims to deliver a seamless audio experience when steaming single audios as well as playlists.

## Features

- **Swiftly Developed**: Robin is built entirely with Swift, making it efficient and future-proof.
- **iOS Compatibility**: Designed to work with iOS 15.0 and later.
- **Open-Source Freedom**: Robin is an independent package, allowing the community to contribute and enhance its capabilities.
- **Underlying Power**: Relies on the robust AV Player for audio handling.
- **Versatile Source Handling**: Seamlessly play streaming sources as well as local files.
- **Offline Support**: Robin incorporates audio caching for offline playback, ensuring uninterrupted listening.
- **Playlist Prowess**: Organize, manage, and play your favorite tunes with playlist support.
- **Podcast Perfection**: Not just music, but Robin supports podcasts, tested up to audio lengths of 2 hours!

## Audio States

Robin broadcasts various audio states to keep you informed about the playback process:

- `buffering`: Audio is buffering.
- `failed`: Encountered an error and can't play the audio.
- `loaded`: Audio is loaded and primed for playback.
- `loading`: Audio is in the process of loading.
- `paused`: Playback has been paused.
- `playing`: Your audio is playing.
- `stopped`: Playback has been halted.
- `finished`: Your audio has completed playing.

## Audio Types

To play audio, Robin requires the following key struct:

### RobinSoundSource

This struct indicates the audio source.

```swift
public struct RobinSoundSource {
    var url: URL
    var metadata: RobinSoundMetadata?

    public init(url: URL, metadata: RobinSoundMetadata? = nil) {
        self.url = url
        self.metadata = metadata
    }
}
```

## Usage

Here's a quick guide to get you started:

### Loading a Single Audio

To play a specific track, use the following code:

```swift
@ObservedObject var player: Robin = .shared

let songLink: String = "https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_1OMB_MP3.mp3"
guard let soundURL = URL(string: songLink) else { return }
let sound = RobinSoundSource(url: soundURL, metadata: RobinSoundMetadata(title: "Sample Audio", artist: "Robin / The Guardian", image: UIImage(named: "testingAudioImage1")!))
player.loadSingle(source: sound, autostart: false)
```

### Loading Multiple Audios

To play multiple audios, use the following code:

```swift
let multipleSoundSources: [RobinSoundSource] = [
    RobinSoundSource(url: URL(string: "https://rntp.dev/example/Lullaby%20(Demo).mp3")!, metadata: RobinSoundMetadata(title: "Lullaby", artist: "Robin / The Guardian", image: UIImage(named: "testingAudioImage1")!)),
    RobinSoundSource(url: URL(string: "https://rntp.dev/example/Rhythm%20City%20(Demo).mp3")!, metadata: RobinSoundMetadata(title: "Rhythm City", artist: "Robin / The Guardian", image: UIImage(named: "testingAudioImage2")!)),
    RobinSoundSource(url: URL(string: "https://traffic.libsyn.com/atpfm/atp545.mp3")!, metadata: RobinSoundMetadata(title: "Chapters", artist: "Robin / The Guardian", image: UIImage(named: "testingAudioImage3")!))
]

@ObservedObject var player: Robin = .shared
player.loadPlaylist(audioSounds: multipleSoundSources, autostart: false)
```

### Caching Audios

The following sample code shows and example to cache an audio:

```swift
// Caching the audio
Task(priority: .background) { // This can be Task.detached
    do {
        guard let url = URL(string: audioUrl) else { return }
        try await player.saveAudioToCache(soundUrl: url)
        self.audioCached = true
    } catch (let error) {
        print(error)
    }
}

//Playing the cached audio. Here, sound has the same URL as audioUrl
@ObservedObject var player: Robin = .shared
player.loadSingle(source: sound, autostart: false, useCache: true)
```
--------------------

##### Looking forward to your contributions and feedback for Robin! 🎶🚀
##### iOS Development Team - The Guardian
