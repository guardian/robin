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

    func testSeek() async {
        let robin = Robin.shared
        await robin.seek(to: 20.0)
        // Add assertions here to check if audio playback position is correctly set to 20 seconds.
    }

    /// Dismissing the miniplayer calls `pause(removeFromNowPlaying: true)`, which clears the
    /// "Now Playing" dictionary. That must not be mistaken for playback having completed,
    /// otherwise a dismissal is reported downstream as a listen-to-the-end.
    @MainActor
    func testPauseRemovingNowPlayingInfoDoesNotReportFinished() async throws {
        let robin = Robin.shared
        let recorder = StateRecorder()
        robin.delegate = recorder
        defer { robin.delegate = nil }

        robin.pause(removeFromNowPlaying: true)

        // State changes are published asynchronously on the main actor, and `updateNowPlaying()`
        // hops through `DispatchQueue.main.asyncAfter`, so give both a chance to run.
        try await Task.sleep(nanoseconds: 500_000_000)

        let states = recorder.states
        XCTAssertFalse(states.contains(.finished),
                       "Clearing the Now Playing info must not report playback as finished. Observed: \(states)")
        XCTAssertNotEqual(robin.currentState, .finished)
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

/// Records every state Robin reports, so tests can assert on the full transition sequence
/// rather than only the final value.
@MainActor
final class StateRecorder: RobinDelegate {

    private(set) var states: [RobinAudioState] = []

    nonisolated func didUpdateState(state: RobinAudioState) {
        Task { @MainActor in
            self.states.append(state)
        }
    }
}
