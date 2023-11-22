//
//  File.swift
//  
//
//  Created by Usman Nazir on 22/11/2023.
//

import Foundation

public protocol RobinDelegate {
    
    func didUpdateState(state: RobinAudioState)
    func didUpdateMedia(media: RobinAudioSource)
}
