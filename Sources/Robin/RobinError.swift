//
//  RobinError.swift
//  Robin
//

import Foundation

/// Describes the set of possible errors in the Robin Player.
public enum RobinError: Error {
    
    /// Indicates that the downloading of audio failed.
    /// This could be due to various reasons such as network issues or the audio source being unavailable.
    case audioDownloadFailure
    
    /// Represents an error where the audio cache isn't available.
    /// This might occur if there's insufficient storage space or other cache-related issues.
    case audioCacheNotAvailable
}
