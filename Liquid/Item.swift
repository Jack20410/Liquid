//
//  Item.swift
//  Liquid
//
//  Created by Bao Le on 8/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
