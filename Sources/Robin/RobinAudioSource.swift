//
//  RobinSoundSource.swift
//  Robin
//

import Foundation
import UIKit

/// Represents the source of an audio in the Robin system.
public struct RobinAudioSource {
    
    /// The URL pointing to the sound resource.
    public var url: URL
    
    /// Metadata associated with the sound, such as title, artist, and album.
    /// This is optional and may not always be provided.
    public var metadata: RobinAudioMetadata?
    
    public init(url: URL, metadata: RobinAudioMetadata? = nil) {
        self.url = url
        self.metadata = metadata
    }
    
    /// Sample sound source
    public static let sample: RobinAudioSource = .init(url: URL(string: "https://rntp.dev/example/Lullaby%20(Demo).mp3")!,
                                                metadata: .sample)
}

/// Represents the metadata associated with a `RobinSoundSource`.
public struct RobinAudioMetadata {
    
    /// The title of the sound. This could represent the name of a song, sound effect, or any other title.
    public var title: String?
    
    /// The artist or creator of the sound. This is relevant particularly for songs or tracks.
    public var artist: String?
    
    /// This represents a thumbnail, or any related image.
    /// Ideally should be 250x250
    public var image: UIImage?
    
    public init(title: String? = nil, artist: String? = nil, image: UIImage? = nil) {
        self.title = title
        self.artist = artist
        self.image = image
    }
    
    /// Sample metadata
    public static let sample: RobinAudioMetadata = .init(title: "Sample Audio Title",
                                                  artist: "The Guardian")
}
