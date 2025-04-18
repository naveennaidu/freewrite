// Swift 5.0
//
//  HeartEmoji.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI

struct HeartEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var offset: CGFloat = 0
}
