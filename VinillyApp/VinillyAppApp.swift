//
//  VinillyAppApp.swift
//  VinillyApp
//
//  Created by Francesca Coppola on 18/10/2026.
//

import SwiftUI
import SwiftData

@main
struct VinillyAppApp: App {
    
    init() {
        // Crea la cartella Application Support se non esiste (risolve il Sandbox Code=512)
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Vinyl.self)
    }
}
