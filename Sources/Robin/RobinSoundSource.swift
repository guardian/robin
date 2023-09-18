//
//  RobinSoundSource.swift
//  Robin
//

import Foundation
import UIKit

/// Represents the source of a sound in the Robin system.
public struct RobinSoundSource {
    
    /// The URL pointing to the sound resource.
    var url: URL
    
    /// Metadata associated with the sound, such as title, artist, and album.
    /// This is optional and may not always be provided.
    var metadata: RobinSoundMetadata?
    
    public init(url: URL, metadata: RobinSoundMetadata? = nil) {
        self.url = url
        self.metadata = metadata
    }
    
    /// Sample sound source
    static let sample: RobinSoundSource = .init(url: URL(string: "https://rntp.dev/example/Lullaby%20(Demo).mp3")!,
                                                metadata: .sample)
}

/// Represents the metadata associated with a `RobinSoundSource`.
public struct RobinSoundMetadata {
    
    /// The title of the sound. This could represent the name of a song, sound effect, or any other title.
    var title: String?
    
    /// The artist or creator of the sound. This is relevant particularly for songs or tracks.
    var artist: String?
    
    /// This represents a thumbnail, or any related image.
    /// Ideally should be 250x250
    var image: UIImage?
    
    public init(title: String? = nil, artist: String? = nil, image: UIImage? = nil) {
        self.title = title
        self.artist = artist
        self.image = image
    }
    
    /// Sample metadata
    static let sample: RobinSoundMetadata = .init(title: "Sample Audio Title",
                                                  artist: "The Guardian")
}
