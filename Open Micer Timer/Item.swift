//
//  Item.swift
//  Open Micer Timer
//
//  Created by Taylor Drew on 12/4/25.
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
