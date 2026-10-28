//
//  RobinTests.swift
//  Robin
//

import XCTest
import AVFoundation
import MediaPlayer
@testable import Robin

/// Tests run against the `Robin.shared` singleton, because that is the only way the library is
/// ever used. Every test therefore resets the player in `setUp`/`tearDown` so state cannot leak
/// between cases.
///
/// Audio is generated locally as a silent WAV rather than streamed from the sample URL, so the
/// suite is deterministic and does not need a network connection.
final class RobinTests: XCTestCase {

    /// Temporary audio files created by a test, deleted once it finishes.
    private var temporaryFiles: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        await resetPlayer()
    }

    override func tearDown() async throws {
        await resetPlayer()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    // MARK: - Loading

    func testLoadSingleReportsTheMediaAndItsDuration() async {
        let robin = Robin.shared
        let duration = await loadSingleLocalAudio(title: "Lullaby")

        XCTAssertEqual(robin.currentMedia?.metadata?.title, "Lullaby")
        XCTAssertEqual(duration, Self.defaultDuration, accuracy: 0.2)
        XCTAssertEqual(robin.audioLength, Self.defaultDuration, accuracy: 0.2)
        XCTAssertFalse(robin.isPlayingQueue, "A single source must not put the player in queue mode.")
    }

    func testLoadPlaylistPopulatesTheQueue() async {
        let robin = Robin.shared
        let sources = makeLocalSources(titles: ["One", "Two", "Three"])

        robin.loadPlaylist(audioSounds: sources, autostart: false)
        await waitUntil("the first track to become current") { robin.currentMedia != nil }

        XCTAssertTrue(robin.isPlayingQueue)
        XCTAssertEqual(robin.audioQueue.count, 3)
        XCTAssertEqual(robin.audioIndex, 0)
        XCTAssertEqual(robin.currentMedia?.metadata?.title, "One")
    }

    func testLoadingAnEmptyPlaylistLoadsNothing() async {
        let robin = Robin.shared

        robin.loadPlaylist(audioSounds: [], autostart: false)

        XCTAssertTrue(robin.audioQueue.isEmpty)
        XCTAssertEqual(robin.audioIndex, 0)
        XCTAssertNil(robin.currentMedia, "An empty playlist must not leave stale media loaded.")
    }

    // MARK: - Queue navigation

    func testNextAndPreviousMoveThroughTheQueue() async {
        let robin = Robin.shared
        let sources = makeLocalSources(titles: ["One", "Two", "Three"])
        robin.loadPlaylist(audioSounds: sources, autostart: false)
        await waitUntil("the first track to become current") { robin.currentMedia != nil }

        robin.next()
        XCTAssertEqual(robin.audioIndex, 1)
        await waitUntil("the second track to become current") { robin.currentMedia?.metadata?.title == "Two" }

        robin.next()
        XCTAssertEqual(robin.audioIndex, 2)
        await waitUntil("the third track to become current") { robin.currentMedia?.metadata?.title == "Three" }

        robin.previous()
        XCTAssertEqual(robin.audioIndex, 1)
        await waitUntil("the second track to become current again") { robin.currentMedia?.metadata?.title == "Two" }
    }

    func testNextAtTheEndOfTheQueueDoesNothing() async {
        let robin = Robin.shared
        let sources = makeLocalSources(titles: ["Only"])
        robin.loadPlaylist(audioSounds: sources, autostart: false)
        await waitUntil("the track to become current") { robin.currentMedia != nil }

        robin.next()

        XCTAssertEqual(robin.audioIndex, 0, "There is no track after the last one.")
        XCTAssertEqual(robin.currentMedia?.metadata?.title, "Only")
    }

    func testPreviousAtTheStartOfTheQueueDoesNothing() async {
        let robin = Robin.shared
        let sources = makeLocalSources(titles: ["One", "Two"])
        robin.loadPlaylist(audioSounds: sources, autostart: false)
        await waitUntil("the first track to become current") { robin.currentMedia != nil }

        robin.previous()

        XCTAssertEqual(robin.audioIndex, 0, "There is no track before the first one.")
        XCTAssertEqual(robin.currentMedia?.metadata?.title, "One")
    }

    // MARK: - Transport

    func testResetClearsPlaybackState() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()
        await seekPlayerDirectly(to: 5)

        robin.reset()

        XCTAssertNil(robin.currentMedia)
        XCTAssertEqual(robin.audioLength, 0)
        XCTAssertEqual(robin.elapsedTime, 0)
        XCTAssertEqual(robin.remainingTime, 0)
        XCTAssertEqual(robin.bufferedTime, 0)
        XCTAssertEqual(robin.playbackRate, 1.0)
        await waitUntil("the player to return to standby") { robin.currentState == .standby }
    }

    func testChangePlaybackRateUpdatesTheRate() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()

        robin.changePlaybackRate(rate: 1.5)

        XCTAssertEqual(robin.playbackRate, 1.5)
    }

    func testSeekMovesThePlayhead() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()

        await robin.seek(to: 20.0)
        robin.pause()

        XCTAssertEqual(currentTime(), 20.0, accuracy: 2.0)
    }

    func testReplayRestartsFromTheBeginningAndResumesPlayback() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()
        await seekPlayerDirectly(to: 15)

        robin.replay()

        await waitUntil("the playhead to return to the start") { self.currentTime() < 2.0 }
        await waitUntil("playback to resume after replaying") { robin.player.rate > 0 }
        robin.pause()
    }

    // MARK: - Finishing playback

    /// Reaching the end of an item must report `.finished`, and must leave the playhead parked at
    /// the end. Rewinding here was what made `.finished` unstable: the rewind raced the
    /// `timeControlStatus` observer, which then reported `.paused` over the top of it.
    func testPlayingToTheEndReportsFinishedAndParksAtTheEnd() async {
        let robin = Robin.shared
        let duration = await loadSingleLocalAudio()
        let recorder = StateRecorder()
        robin.delegate = recorder

        await parkPlayheadAtEndOfItem(duration: duration)
        postDidPlayToEndTime()

        await waitUntil("playback to be reported as finished") { robin.currentState == .finished }
        XCTAssertTrue(recorder.states.contains(.finished))

        // An auto-rewind would seek asynchronously, so give one a chance to land before
        // asserting on the position. Without this the test passes even when rewinding.
        try? await Task.sleep(nanoseconds: 750_000_000)

        XCTAssertEqual(currentTime(), duration, accuracy: 1.0,
                       "A finished item must stay parked at its end rather than rewinding.")
    }

    /// Regression test for the `.finished` -> `.paused` race. Once finished, no later state change
    /// may overwrite `.finished`, otherwise the end of an article is never reported downstream.
    func testFinishedStateIsNotClobberedByTheSubsequentPausedTransition() async {
        let robin = Robin.shared
        let duration = await loadSingleLocalAudio()
        let recorder = StateRecorder()
        robin.delegate = recorder

        await parkPlayheadAtEndOfItem(duration: duration)
        postDidPlayToEndTime()
        await waitUntil("playback to be reported as finished") { robin.currentState == .finished }

        // Give the time control observer and the Now Playing update every chance to report over it.
        try? await Task.sleep(nanoseconds: 750_000_000)

        XCTAssertEqual(robin.currentState, .finished,
                       "Observed states: \(recorder.states)")
        XCTAssertEqual(recorder.states.last, .finished,
                       "`.finished` must be the final reported state. Observed: \(recorder.states)")
    }

    /// Because a finished item parks at its end, playing it again has to rewind first, otherwise
    /// the user taps play and nothing happens.
    func testPlayingAfterFinishingRewindsToTheStart() async {
        let robin = Robin.shared
        let duration = await loadSingleLocalAudio()
        await parkPlayheadAtEndOfItem(duration: duration)
        postDidPlayToEndTime()
        await waitUntil("playback to be reported as finished") { robin.currentState == .finished }

        robin.play()

        await waitUntil("the playhead to rewind to the start") { self.currentTime() < 2.0 }
        robin.pause()
    }

    /// The lazy rewind is gated on the item having completed, not on the reported state, so that
    /// resuming mid-track never throws away the listener's position.
    func testPlayingMidTrackDoesNotRewind() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()
        await seekPlayerDirectly(to: 10)

        robin.play()
        try? await Task.sleep(nanoseconds: 300_000_000)
        robin.pause()

        XCTAssertGreaterThan(currentTime(), 9.0,
                             "Resuming mid-track must not rewind the playhead to the start.")
    }

    // MARK: - Pausing

    /// Dismissing the miniplayer calls `pause(removeFromNowPlaying: true)`, which clears the
    /// "Now Playing" dictionary. That must not be mistaken for playback having completed,
    /// otherwise dismissing the player is reported downstream as a listen-to-the-end.
    func testPauseRemovingNowPlayingInfoDoesNotReportFinished() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()
        await seekPlayerDirectly(to: 5)

        let recorder = StateRecorder()
        robin.delegate = recorder

        robin.pause(removeFromNowPlaying: true)

        // State changes are published asynchronously, and `updateNowPlaying()` hops through
        // `DispatchQueue.main.asyncAfter`, so give both a chance to run.
        try? await Task.sleep(nanoseconds: 750_000_000)

        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo,
                     "The Now Playing dictionary should have been cleared.")
        XCTAssertFalse(recorder.states.contains(.finished),
                       "Clearing the Now Playing info must not report playback as finished. Observed: \(recorder.states)")
        XCTAssertNotEqual(robin.currentState, .finished)
    }

    /// The same dismissal, but from a playing state, which is how it actually happens in the app.
    func testPauseWhilePlayingReportsPausedRatherThanFinished() async {
        let robin = Robin.shared
        await loadSingleLocalAudio()
        await seekPlayerDirectly(to: 5)

        robin.play()
        try? await Task.sleep(nanoseconds: 300_000_000)

        let recorder = StateRecorder()
        robin.delegate = recorder

        robin.pause(removeFromNowPlaying: true)
        try? await Task.sleep(nanoseconds: 750_000_000)

        XCTAssertFalse(recorder.states.contains(.finished),
                       "Pausing mid-track must never report playback as finished. Observed: \(recorder.states)")
        XCTAssertNotEqual(robin.currentState, .finished)
    }
}

// MARK: - Helpers

extension RobinTests {

    /// Duration of the generated test audio. Deliberately not a whole number of seconds:
    /// `audioCompleted()` compares `Int(currentTime)` with `Int(duration)`, so a fractional
    /// duration gives the test a stable window in which the item counts as completed.
    static let defaultDuration: Double = 30.5

    /// Returns the player's current position in seconds.
    func currentTime() -> Double {
        CMTimeGetSeconds(Robin.shared.player.currentTime())
    }

    /// Restores the shared player to a clean, stopped state.
    func resetPlayer() async {
        let robin = Robin.shared
        robin.delegate = nil
        robin.pause()
        robin.reset()
        robin.isPlayingQueue = false
        robin.audioQueue = []
        robin.audioIndex = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        // Let any in-flight state updates land before the next test starts observing.
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Loads a locally generated audio file without starting playback, and waits until its
    /// duration has been resolved.
    @discardableResult
    func loadSingleLocalAudio(title: String = "Test Audio") async -> Double {
        let robin = Robin.shared
        robin.loadSingle(source: makeLocalSource(title: title), autostart: false)
        await waitUntil("the asset duration to load") { robin.audioLength > 0 }
        return robin.audioLength
    }

    /// Moves the playhead without going through Robin's own `seek(to:)`, so a test can set up a
    /// position without also triggering playback logic.
    func seekPlayerDirectly(to seconds: Double) async {
        await Robin.shared.player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000),
                                       toleranceBefore: .zero,
                                       toleranceAfter: .zero)
    }

    /// Parks the playhead inside the final second of the item, which is what `audioCompleted()`
    /// treats as having played to the end.
    func parkPlayheadAtEndOfItem(duration: Double) async {
        await seekPlayerDirectly(to: max(0, duration - 0.2))
    }

    /// Simulates the item reaching its end, which is what `AVPlayer` posts during real playback.
    func postDidPlayToEndTime(file: StaticString = #filePath, line: UInt = #line) {
        guard let item = Robin.shared.player.currentItem else {
            XCTFail("Expected the player to have a current item loaded.", file: file, line: line)
            return
        }
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
    }

    /// Polls until `condition` holds, or fails the test once `timeout` elapses.
    @discardableResult
    func waitUntil(_ description: String,
                   timeout: TimeInterval = 10,
                   file: StaticString = #filePath,
                   line: UInt = #line,
                   condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        if condition() { return true }
        XCTFail("Timed out after \(timeout)s waiting for \(description).", file: file, line: line)
        return false
    }

    /// Builds several audio sources at once, each with a distinct title so queue order is testable.
    func makeLocalSources(titles: [String]) -> [RobinAudioSource] {
        titles.map { makeLocalSource(title: $0, seconds: 2.5) }
    }

    /// Writes a silent WAV to a temporary file and wraps it in a `RobinAudioSource`.
    func makeLocalSource(title: String, seconds: Double = RobinTests.defaultDuration) -> RobinAudioSource {
        // A unique file name matters: `getAudioUrl` consults the cache by last path component,
        // so a predictable name could be shadowed by a leftover file in the documents directory.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("robin-test-\(UUID().uuidString).wav")
        do {
            try SilentAudioFile.write(to: url, seconds: seconds)
        } catch {
            XCTFail("Could not write test audio: \(error)")
        }
        temporaryFiles.append(url)
        return RobinAudioSource(url: url, metadata: RobinAudioMetadata(title: title, artist: "Tests"))
    }
}

/// Records every state Robin reports, so tests can assert on the whole transition sequence rather
/// than only the final value.
final class StateRecorder: RobinDelegate {

    private let lock = NSLock()
    private var recorded: [RobinAudioState] = []

    var states: [RobinAudioState] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func didUpdateState(state: RobinAudioState) {
        lock.lock()
        recorded.append(state)
        lock.unlock()
    }
}

/// Generates a silent, uncompressed WAV file, so tests have real playable audio of a known
/// duration without reaching out to the network.
enum SilentAudioFile {

    static func write(to url: URL, seconds: Double, sampleRate: Int = 8_000) throws {
        let channels = 1
        let bitsPerSample = 16
        let bytesPerFrame = channels * bitsPerSample / 8
        let frameCount = Int((Double(sampleRate) * seconds).rounded())
        let dataSize = frameCount * bytesPerFrame

        var data = Data()
        func ascii(_ string: String) {
            data.append(contentsOf: Array(string.utf8))
        }
        func uInt32(_ value: Int) {
            var littleEndian = UInt32(value).littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        func uInt16(_ value: Int) {
            var littleEndian = UInt16(value).littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        ascii("RIFF")
        uInt32(36 + dataSize)
        ascii("WAVE")

        ascii("fmt ")
        uInt32(16)                              // Size of this chunk.
        uInt16(1)                               // Format: uncompressed PCM.
        uInt16(channels)
        uInt32(sampleRate)
        uInt32(sampleRate * bytesPerFrame)      // Byte rate.
        uInt16(bytesPerFrame)                   // Block align.
        uInt16(bitsPerSample)

        ascii("data")
        uInt32(dataSize)
        data.append(Data(count: dataSize))      // Silence.

        try data.write(to: url)
    }
}
