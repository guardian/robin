//
//  AudioState.swift
//  Robin
//

/// Represents the various states an audio playback can be in.
///
/// - Note: This enumeration provides a raw `String` value for each state.
public enum AudioState: String {
    
    /// This is the initial state when the player is waiting to load an audio.
    case standby
    
    /// The audio is currently buffering content.
    case buffering
    
    /// The audio has encountered an error and failed to load or play.
    case failed
    
    /// The audio content has been loaded and is ready to play.
    case loaded
    
    /// The audio content is currently being loaded.
    case loading
    
    /// The audio playback is paused.
    case paused
    
    /// The audio is currently playing.
    case playing
    
    /// The audio playback has finished.
    case finished
}
