//
//  DatabaseService.swift
//  VinillyApp
//
//  Created by Francesca Coppola on 19/10/2026.
//
import Foundation
import SQLite3
import SwiftData

class DatabaseService {
    static let shared = DatabaseService()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
    }

    private func openDatabase() {
        guard let dbPath = Bundle.main.path(forResource: "vinilly_offline", ofType: "db") else {
            print("⚠️ Database vinilly_offline.db non trovato nel bundle.")
            return
        }

        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("⚠️ Impossibile aprire il database SQLite.")
        } else {
            print("✅ Database SQLite offline pronto!")
        }
    }

    func searchByBarcode(_ code: String) -> Vinyl? {
        guard let db = db else { return nil }
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Calcola la variante senza zero iniziale (da EAN-13 a UPC-A)
        var altCode = cleanCode
        if cleanCode.hasPrefix("0") && cleanCode.count == 13 {
            altCode = String(cleanCode.dropFirst())
        } else if cleanCode.count == 12 {
            altCode = "0" + cleanCode
        }

        // Cerchiamo entrambe le varianti nella query SQL
        let query = """
            SELECT barcode, title, artist, genre, year, coverUrl 
            FROM vinyls 
            WHERE barcode = ? OR barcode = ? 
            LIMIT 1;
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            // Parametro 1: cleanCode
            sqlite3_bind_text(stmt, 1, (cleanCode as NSString).utf8String, -1, nil)
            // Parametro 2: altCode (senza lo 0)
            sqlite3_bind_text(stmt, 2, (altCode as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) == SQLITE_ROW {
                let barcode = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let artist = String(cString: sqlite3_column_text(stmt, 2))
                
                let genre = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : "Pop"
                let year = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : "N/D"
                let coverUrl = sqlite3_column_text(stmt, 5) != nil ? String(cString: sqlite3_column_text(stmt, 5)) : nil

                return Vinyl(
                    barcode: barcode,
                    title: title,
                    artist: artist,
                    genre: genre,
                    year: year,
                    coverUrl: coverUrl
                )
            }
        } else {
            print("❌ Errore SQLite prepare: \(String(cString: sqlite3_errmsg(db)))")
        }
        return nil
    }
    
    
    func fetchOtherVinylsByArtist(artist: String, excludingBarcode: String) -> [Vinyl] {
        guard let db = db, !artist.isEmpty else { return [] }
        var results: [Vinyl] = []
        
        let sql = """
            SELECT barcode, title, artist, genre, year, coverUrl 
            FROM vinyls 
            WHERE artist = ? AND barcode != ? 
            LIMIT 20;
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (artist as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (excludingBarcode as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let barcode = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let artist = String(cString: sqlite3_column_text(stmt, 2))
                let genre = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : "Rock"
                let year = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : "N/D"
                let coverUrl: String? = sqlite3_column_text(stmt, 5) != nil ? String(cString: sqlite3_column_text(stmt, 5)) : nil
                
                results.append(Vinyl(
                    barcode: barcode,
                    title: title,
                    artist: artist,
                    genre: genre,
                    year: year,
                    coverUrl: coverUrl
                ))
            }
        }
        return results
    }
    
    func searchByText(query: String) -> [Vinyl] {
        guard let db = db, !query.isEmpty else { return [] }
        var results: [Vinyl] = []
        let sql = "SELECT barcode, title, artist, genre, year, coverUrl FROM vinyls WHERE title LIKE ? OR artist LIKE ? LIMIT 25;"
        var stmt: OpaquePointer?

        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let pattern = "%\(query)%" as NSString
            sqlite3_bind_text(stmt, 1, pattern.utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, pattern.utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let barcode = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let artist = String(cString: sqlite3_column_text(stmt, 2))
                let genre = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : "Rock"
                let year = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : "N/D"
                let coverUrl = sqlite3_column_text(stmt, 5) != nil ? String(cString: sqlite3_column_text(stmt, 5)) : nil

                results.append(Vinyl(
                    barcode: barcode,
                    title: title,
                    artist: artist,
                    genre: genre,
                    year: year,
                    coverUrl: coverUrl
                ))
            }
        }
        return results
    }

    deinit {
        sqlite3_close(db)
    }
}
