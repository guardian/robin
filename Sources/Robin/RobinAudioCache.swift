//
//  RobinAudioService.swift
//  Robin
//

import Foundation

/// Protocol oriented programming approach to an Audio Cache Service. This service is responsible for handling all the audio caching.
/// This is not currently in use but would be used in a future feature.
public protocol RobinAudioCache {}

extension RobinAudioCache {
    
    /// Saves an audio file to the app's cache on disk.
    ///
    /// This function asynchronously downloads the audio from the provided URL and saves it to the app's document directory.
    /// - Parameters:
    ///   - cacheKey: The key (filename) under which the audio will be saved.
    ///   - soundUrl: The URL from which the audio file will be downloaded.
    /// - Returns: The local URL where the audio has been saved, or `nil` if the operation fails.
    /// - Throws: `RobinError.audioDownloadFailure` if the audio download or save operation fails.
    @discardableResult
    public func saveAudioToCache(soundUrl: URL) async throws -> URL? {
        return try await Task {
            guard let data = try? Data(contentsOf: soundUrl),
                  let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw RobinError.audioDownloadFailure
            }

            let fileName = soundUrl.lastPathComponent
            let fileURL = directoryURL.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            return fileURL
        }.value
    }
    
    /// Retrieves the local URL of an audio file from the app's cache on disk.
    ///
    /// This function provides the local URL for a cached audio file based on the provided cache key.
    /// - Parameter cacheKey: The key (filename) under which the audio has been saved.
    /// - Returns: The local URL of the cached audio.
    /// - Throws: `RobinError.audioCacheNotAvailable` if the app's document directory is not available.
    public func getAudioFromCache(soundUrl: URL) throws -> URL {
        guard let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RobinError.audioCacheNotAvailable
        }
        let fileName = soundUrl.lastPathComponent
        let fileURL = directoryURL.appendingPathComponent(fileName)
        if #available(iOS 16, *) {
            if !FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                throw RobinError.audioCacheNotAvailable
            }
        } else {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                throw RobinError.audioCacheNotAvailable
            }
        }
        return fileURL
    }
}
