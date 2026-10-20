//
//  Vinyl.swift
//  VinillyApp
//
//  Created by Francesca Coppola on 19/10/2026.
//

import Foundation
import SwiftData

@Model
final class Vinyl {
    @Attribute(.unique) var barcode: String
    var title: String
    var artist: String
    var genre: String
    var year: String
    var coverUrl: String?
    var addedAt: Date = Date()

    init(barcode: String, title: String, artist: String, genre: String, year: String, coverUrl: String? = nil, addedAt: Date = Date()) {
        self.barcode = barcode
        self.title = title
        self.artist = artist
        self.genre = genre
        self.year = year
        self.coverUrl = coverUrl
        self.addedAt = addedAt
    }
}
