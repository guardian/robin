//
//  Robin.swift
//  Robin
//

import AVFoundation
import MediaPlayer

public class Robin: NSObject, ObservableObject {
    
    /// Shared instance of the `RobinPlayer`.
    public static var shared: Robin = Robin()
    
    /// The preferred buffer duration for the audio stream.
    private var preferredBufferDuration: Double = 2.0
    
    /// An observer for the player's time control status.
    private var timeControlStatusObserver: NSKeyValueObservation?
    
    private var bufferingStatusObserver: NSKeyValueObservation?
    
    /// The current media being played or processed.
    @Published public var currentMedia: RobinAudioSource?
    
    /// The current state of the audio player.
    @Published public var currentState: RobinAudioState = .standby
    
    /// The elapsed time since the audio started playing.
    @Published public var elapsedTime: Double = 0.0
    
    /// The remaining time left for the audio to finish playing.
    @Published public var remainingTime: Double = 0.0
    
    /// The current bufferred time
    @Published public var bufferedTime: Double = 0.0
    
    /// The total length of the current audio.
    @Published public var audioLength: Double = 0.0
    
    /// The total length of the current audio.
    @Published public var playbackRate: Float = 1.0
    
    /// A flag indicating if a queue of audios is being played.
    public var isPlayingQueue = false
    
    /// A queue of audio sources to be played.
    public var audioQueue: [RobinAudioSource] = []
    
    /// The index of the current audio in the queue.
    public var audioIndex: Int = 0
    
    /// The underlying AVPlayer used for streaming audio.
    private var player = AVPlayer()
    
    /// A flag used  by Robin to determine whether to useCache if available.
    private var useCache: Bool = true
    
    /// Initializes the `RobinPlayer` and prepares it for playback.
    override init() {
        super.init()
        preparePlayer()
    }
    
    /// Configures the audio session for playback.
    private func preparePlayer() {
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(AVAudioSession.Category.playback)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error as NSError {
                print("Robin / " + error.localizedDescription)
            }
        } catch let error as NSError {
            print("Robin / " + error.localizedDescription)
        }
    }
}

// MARK: - Audio Initialization functions
extension Robin: RobinAudioCache {
    
    /// Loads a playlist of audio sources and begins playback based on the `autostart` flag.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// let multipleSoundSources: [RobinAudioSource] = [...]
    /// player.loadPlaylist(audioSounds: multipleSoundSources)
    /// ```
    ///
    /// - Parameters:
    ///   - audioSounds: The array of `RobinAudioSource` representing the playlist.
    ///   - autostart: A flag indicating whether to start playback automatically upon loading. Default is `true`.
    public func loadPlaylist(audioSounds: [RobinAudioSource], autostart: Bool = true, useCache: Bool = true) {
        isPlayingQueue = true
        audioQueue = audioSounds
        audioIndex = 0
        self.useCache = useCache
        guard audioQueue.count > 0 else { return }
        setupRemoteTransportControls()
        startAudio(sound: audioQueue[audioIndex], autoStart: autostart)
    }
    
    /// Loads a single audio source for playback, with an option to begin playing immediately.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// let singleSoundSource: RobinAudioSource = .init(...)
    /// player.loadSingle(sound: singleSoundSource)
    /// ```
    ///
    /// - Parameters:
    ///   - source: The `RobinAudioSource` object representing the audio source to be played.
    ///   - autostart: A flag indicating whether to start playback automatically upon loading. Default is `true`.
    public func loadSingle(source: RobinAudioSource, autostart: Bool = true, useCache: Bool = true) {
        isPlayingQueue = false
        self.useCache = useCache
        player.pause()
        setupRemoteTransportControls()
        startAudio(sound: source, autoStart: autostart)
    }
    
    /// Plays a new audio source on the player. This method is used for both single and playlist audios.
    ///
    /// - Parameter sound: The new `RobinAudioSource` object to be played.
    private func startAudio(sound: RobinAudioSource, autoStart: Bool = true) {
        self.audioObserverStateChanged(state: .loading)
        let audioUrl = getAudioUrl(soundUrl: sound.url)
        let item = AVPlayerItem(asset: AVAsset(url: audioUrl))
        item.preferredForwardBufferDuration = preferredBufferDuration
        self.player.replaceCurrentItem(with: item)
        observeTimeChanges()
        observeCurrentState()
        setupSystemControls(sound: sound)
        updateCurrentMedia(sound: sound)
        audioObserverStateChanged(state: .playing)
        if autoStart { play() }
    }
    
    /// Updates the `currentMedia` property to reflect the media currently being played.
    ///
    /// - Parameter sound: The `RobinAudioSource` object that is currently active.
    private func updateCurrentMedia(sound: RobinAudioSource) {
        Task { @MainActor in
            self.currentMedia = sound
        }
    }
    
    /// This function returns the LocalURL of the Cache if available, otherwise, it returns the original URL to stream the audio.
    ///
    /// - Parameter soundUrl: The URL of the sound file.
    private func getAudioUrl(soundUrl: URL) -> URL {
        do {
            return try getAudioFromCache(soundUrl: soundUrl)
        } catch {
            return soundUrl
        }
    }
}

// MARK: - Observer methods
/// An extension to the `RobinPlayer` class, providing methods to handle audio playback behaviors, state observation, and system controls.
extension Robin {
    
    /// Observes the elapsed time of the current audio track being played.
    ///
    /// This method adds a periodic time observer to the `player`, and on each tick, updates the `elapsedTime` property to reflect the playback's current position.
    private func observeTimeChanges() {
        self.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1000),
                                            queue: DispatchQueue.global(qos: .userInteractive),
                                            using: { time in
            
            // If the player is playing, then update the time
            guard self.currentState == .playing else { return }
            Task.detached(priority: .high) { @MainActor in
                self.elapsedTime = CMTimeGetSeconds(time).rounded(.down)
                self.remainingTime = self.audioLength - CMTimeGetSeconds(time).rounded(.up)
            }
        })
    }
    
    /// Observes and handles the various playback states of the `player`.
    ///
    /// This method sets up notifications and observers to detect when a track finishes playing, pauses, or faces buffering issues. Depending on the detected state, it updates the player's state accordingly.
    private func observeCurrentState() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        timeControlStatusObserver = player.observe(\.timeControlStatus) { [weak self] _, change in
            switch self?.player.timeControlStatus {
            case .paused:
                if self?.audioCompleted() ?? false {
                    self?.audioObserverStateChanged(state: .finished)
                    self?.replay()
                } else {
                    self?.audioObserverStateChanged(state: .paused)
                }
            case .waitingToPlayAtSpecifiedRate:
                self?.audioObserverStateChanged(state: .buffering)
            case .playing:
                self?.audioObserverStateChanged(state: .playing)
            default:
                self?.audioObserverStateChanged(state: .failed)
            }
        }
        
        bufferingStatusObserver = player.currentItem?.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, change in
            if let timeRange = item.loadedTimeRanges.first {
                let bufferedTimeRange = timeRange.timeRangeValue
                let totalBufferedSeconds = CMTimeGetSeconds(bufferedTimeRange.start) + CMTimeGetSeconds(bufferedTimeRange.duration)
                self?.bufferedTime = totalBufferedSeconds
                if CMTimeGetSeconds((self?.player.currentTime())!) > totalBufferedSeconds && self?.currentState != .buffering {
                    Task(priority: .high) {
                        self?.audioObserverStateChanged(state: .buffering)
                    }
                }
            }
        }
    }
    
    /// Sets up the system controls, which includes the lockscreen media controls, for the given audio source.
    /// This method updates the Now Playing info on the lockscreen to reflect the metadata of the currently playing `RobinSoundSource`.
    ///
    /// - Parameter sound: The `RobinSoundSource` object representing the current audio being played.
    private func setupSystemControls(sound: RobinAudioSource) {
        Task { @MainActor in
            do {
                self.audioLength = try await self.audioDuration() ?? .zero
                self.remainingTime = self.audioLength
                setupNowPlaying(sound: sound)
                audioObserverStateChanged(state: .loaded)
            } catch (let error) {
                print("Robin / Some error occured: \(error)")
                audioObserverStateChanged(state: .failed)
            }
        }
    }
}

// MARK: - Playback Controls
/// An extension to the `RobinPlayer` class, providing methods for controlling audio playback including play, pause, and track navigation functionalities.
extension Robin {
    
    /// Starts playing the current audio track.
    ///
    /// This function initiates the playback of the audio using the `player` and ensures
    /// that the Now Playing information is updated accordingly.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.play()
    /// ```
    ///
    /// - Note: You can customize the playback rate by setting the `playbackRate` property before calling this method.
    public func play() {
//        if floor(self.elapsedTime) >= floor(self.audioLength) - 1.5 {
//            replay()
//        } else {
            self.player.rate = self.playbackRate
            updateNowPlaying()
//        }
    }
    
    /// Pauses the playback of the current audio track.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.pause()
    /// ```
    ///
    /// Calls the `pause()` method on the `player` and updates the Now Playing information.
    public func pause() {
        self.player.rate = 0.0
        player.pause()
        updateNowPlaying()
    }
    
    /// Advances to and begins playback of the next audio track in the queue.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.next()
    /// ```
    ///
    /// If the player is in queue mode and the current track isn't the last in the queue, the next track will be loaded and played.
    public func next() {
        guard isPlayingQueue,
              audioIndex+1 < audioQueue.count else { return }
        audioIndex += 1
        pause()
        startAudio(sound: audioQueue[audioIndex])
    }
    
    /// Returns to and begins playback of the previous audio track in the queue.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.previous()
    /// ```
    ///
    /// If the player is in queue mode and the current track isn't the first in the queue, the previous track will be loaded and played.
    public func previous() {
        guard isPlayingQueue,
              audioIndex-1 >= 0 else { return }
        audioIndex -= 1
        pause()
        startAudio(sound: audioQueue[audioIndex])
    }
    
    /// Resets the audio playback to the start of the current track.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.reset()
    /// ```
    ///
    /// Moves the playback position of the `player` to the beginning of the track without affecting its playback state (i.e., whether it's playing or paused).
    public func reset() {
        player = AVPlayer()
        self.currentMedia = nil
        self.audioLength = 0.0
        self.playbackRate = 1.0
        audioObserverStateChanged(state: .standby)
    }
    
    /// Restarts the playback of the current audio track from the beginning.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.replay()
    /// ```
    ///
    /// Resets the audio playback and then starts the playback.
    public func replay() {
        player.seek(to: .zero,
                    toleranceBefore: .init(value: 1, timescale: 100),
                    toleranceAfter: .init(value: 1, timescale: 100)) { _ in
            self.updateNowPlaying()
        }
    }
    
    /// Modifies the speed at which the audio is played.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.changePlaybackRate(rate: 1.5)
    /// ```
    ///
    /// - Parameter rate: The desired playback rate. Typically, `1.0` represents normal speed. Values greater than `1.0` increase playback speed, and values between `0.0` and `1.0` decrease it.
    public func changePlaybackRate(rate: Float) {
        player.rate = rate
        self.playbackRate = rate
        updateNowPlaying()
    }
    
    /// Moves the playback position to a specific time.
    ///
    /// Example:
    ///
    /// ```
    /// let player = Robin.shared
    /// player.seek(to: 20.0) // Seeks audio to 20s mark.
    /// ```
    ///
    /// - Parameter seconds: The desired playback position in seconds. After seeking, updates the Now Playing information.
    public func seek(to seconds: Double) async {
        await player.pause()
        audioObserverStateChanged(state: .buffering)
        await player.seek(to: CMTime(seconds: seconds,
                               preferredTimescale: 1000),
                    toleranceBefore: .init(value: 1, timescale: 1000),
                    toleranceAfter: .init(value: 1, timescale: 1000))
        self.play()
        updateNowPlaying()
    }
}

// MARK: - Remote Transport Controls for the Lockscreen
/// An extension to the `RobinPlayer` class, providing methods for handling remote controls and updating the "Now Playing" information.
extension Robin {
    
    /// Sets up the remote controls for audio playback on connected devices or accessories, such as headphones or the lock screen.
    ///
    /// This method configures remote controls like play, pause, next, previous, and seeking. It also decides the availability of next and previous commands based on whether the player is in a queue mode or not.
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.75, 1.0, 1.25, 1.5]
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] _ in
            if self.player.rate == 0.0 {
                self.play()
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            if self.player.rate != 0.0 {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for seeking.
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] (event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = CMTime(seconds: event.positionTime, preferredTimescale: 1000)
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                return .success
            }
            return .commandFailed
        }
        
        if isPlayingQueue {
            commandCenter.nextTrackCommand.isEnabled = true
            commandCenter.nextTrackCommand.addTarget { [unowned self] _ in
                self.next()
                return .success
            }
            
            commandCenter.previousTrackCommand.isEnabled = true
            commandCenter.previousTrackCommand.addTarget { [unowned self] _ in
                self.previous()
                return .success
            }
        } else {
            commandCenter.skipForwardCommand.isEnabled = true
            commandCenter.skipForwardCommand.preferredIntervals = [15]
            commandCenter.skipForwardCommand.addTarget { [unowned self] _ in
                Task {
                    await self.seek(to: min(audioLength, elapsedTime+15.0))
                }
                return .success
            }
            
            commandCenter.skipBackwardCommand.isEnabled = true
            commandCenter.skipBackwardCommand.preferredIntervals = [15]
            commandCenter.skipBackwardCommand.addTarget { [unowned self] _ in
                Task {
                    await self.seek(to: max(0, elapsedTime-15.0))
                }
                return .success
            }
        }
    }
    
    /// Configures the "Now Playing" information that is displayed on the lock screen or Control Center.
    ///
    /// This method sets the metadata for the audio currently being played using the given `RobinSoundSource` object, including details like title, artist, playback duration, and artwork.
    ///
    /// - Parameter sound: A `RobinSoundSource` object containing the details of the audio being played.
    private func setupNowPlaying(sound: RobinAudioSource) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = sound.metadata?.title ?? ""
        nowPlayingInfo[MPMediaItemPropertyArtist] = sound.metadata?.artist ?? ""
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.audioLength
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(player.currentTime())
        if let image = sound.metadata?.image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Updates the "Now Playing" information during audio playback.
    ///
    /// This method is called during playback to keep the "Now Playing" information in sync with the actual playback status. It updates information such as the playback rate and elapsed playback time.
    private func updateNowPlaying() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player.rate
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(self.player.currentTime())
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
}

// MARK: - Helper functions
/// An extension of the `RobinPlayer` class that conforms to the `AVAudioPlayerDelegate` protocol.
/// This extension handles events from the `AVAudioPlayer` instance and provides methods related to audio playback state management.
extension Robin: AVAudioPlayerDelegate {
    
    /// Invoked when the audio playback reaches its end.
    ///
    /// This method takes appropriate actions once the audio playback has finished. It updates the audio state, synchronizes the "Now Playing" information, and if the player is currently set to play a queue of audio sources, it will proceed to play the next track.
    @objc
    private func playerDidFinishPlaying() {
        audioObserverStateChanged(state: .finished)
        updateNowPlaying()
        if isPlayingQueue {
            next()
        } else {
            replay()
        }
    }
    
    /// Checks if the currently playing audio has completed.
    ///
    /// This function is used for playlist playback when the screen is locked.
    ///
    /// This function determines whether the audio playback has reached its
    /// completion by comparing the current playback time to the total duration
    /// of the audio item. It returns `true` if the playback has completed, and
    /// `false` otherwise.
    ///
    /// - Returns: `true` if audio playback is completed, `false` otherwise.
    private func audioCompleted() -> Bool {
        // Check if the duration is available and not NaN
        guard let duration = player.currentItem?.duration,
              !CMTimeGetSeconds(duration).isNaN
        else { return false }
        
        // Compare the current playback time with the total duration
        return Int(CMTimeGetSeconds(player.currentTime())) == Int(CMTimeGetSeconds(duration))
    }
    
    /// Asynchronously retrieves the duration of the current audio track.
    ///
    /// - Returns: A `Double?` representing the duration of the audio in seconds. Returns `nil` if the duration cannot be determined.
    /// - Throws: An error if the operation fails. The type of error will depend on the underlying failure during the asynchronous operation.
    private func audioDuration() async throws -> Double? {
        return try await self.player.currentItem?.asset.load(.duration).seconds
    }
    
    /// Observes and updates the current playback state of the audio player.
    ///
    /// This method takes a new `AudioState` value as an argument and updates the `currentState` property asynchronously.
    /// The purpose is to ensure that the player's state is always in sync with the actual audio playback state.
    ///
    /// - Parameter state: An `AudioState` enum value indicating the new playback state.
    private func audioObserverStateChanged(state: RobinAudioState) {
        Task.detached(priority: .high) { @MainActor in
            self.currentState = state
        }
    }
}
