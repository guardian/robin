import XCTest
@testable import Robin

// Work in progress
final class RobinTests: XCTestCase {
    
    // This method is called before the invocation of each test method in the class.
    override func setUpWithError() throws {
        Robin.shared.reset()
        Robin.shared.loadSingle(source: .sample)
    }

    func testPlay() {
        let robin = Robin.shared
        robin.play()
        // Add assertions here to check if audio playback has started.
    }

    func testPause() {
        let robin = Robin.shared
        robin.pause()
        // Add assertions here to check if audio playback has paused.
    }

    func testNext() {
        let robin = Robin.shared
        robin.next()
        // Add assertions here to check if the next track in the queue is loaded.
    }

    func testPrevious() {
        let robin = Robin.shared
        robin.previous()
        // Add assertions here to check if the previous track in the queue is loaded.
    }

    func testReset() {
        let robin = Robin.shared
        robin.reset()
        // Add assertions here to check if audio playback position is reset.
    }

    func testReplay() {
        let robin = Robin.shared
        robin.replay()
        // Add assertions here to check if audio playback is restarted from the beginning.
    }

    func testChangePlaybackRate() {
        let robin = Robin.shared
        robin.changePlaybackRate(rate: 1.5)
        // Add assertions here to check if the playback rate is changed.
    }

    func testSeek() {
        let robin = Robin.shared
        robin.seek(to: 20.0)
        // Add assertions here to check if audio playback position is correctly set to 20 seconds.
    }

    // Example test for loading a single audio source:
    func testLoadSingle() {
        let robin = Robin.shared
        let singleAudioSource = RobinAudioSource.sample
        robin.loadSingle(source: singleAudioSource)
        // Add assertions here to check if the single audio source is loaded and played.
    }

    // Example test for loading a playlist:
    func testLoadPlaylist() {
        let robin = Robin.shared
        let multipleAudioSources: [RobinAudioSource] = [/* initialize with appropriate data */]
        robin.loadPlaylist(audioSounds: multipleAudioSources)
        // Add assertions here to check if the playlist is loaded and played.
    }
}
