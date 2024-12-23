//
//  Item.swift
//  Gotama
//
//  Created by Brad Crispin on 12/22/24.
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
