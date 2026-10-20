import os
import sqlite3
import time

master_db = os.path.expanduser("~/Desktop/discogs_vinyls.db")
xcode_db = (
    "/Users/francescacoppola/Desktop/Academy Stuff/VinillyApp/vinilly_offline.db"
)
desktop_db = os.path.expanduser("~/Desktop/vinilly_offline.db")

print("Avvio esportazione completa del catalogo vinili...")
start_time = time.time()

# 1. Rimuovi le vecchie versioni
for p in [xcode_db, desktop_db]:
  if os.path.exists(p):
    try:
      os.remove(p)
    except Exception:
      pass

conn_master = sqlite3.connect(master_db)
cur_master = conn_master.cursor()

conn_out = sqlite3.connect(xcode_db)
cur_out = conn_out.cursor()

# Configurazione veloce per scritture massive in SQLite
cur_out.execute("PRAGMA journal_mode = OFF;")
cur_out.execute("PRAGMA synchronous = 0;")
cur_out.execute("PRAGMA cache_size = 100000;")

# 2. Creiamo la tabella finale
cur_out.execute("""
CREATE TABLE vinyls (
    barcode TEXT PRIMARY KEY,
    title TEXT,
    artist TEXT,
    genre TEXT,
    year TEXT,
    coverUrl TEXT
);
""")

print("Lettura e trasferimento di tutti i vinili con barcode valido...")

# Selezioniamo TUTTI i dischi che hanno un codice a barre non nullo e non vuoto
cur_master.execute("""
    SELECT barcode, title, artist, year, image_path 
    FROM vinyl_releases 
    WHERE barcode IS NOT NULL 
      AND barcode != '' 
      AND barcode != '\\N'
      AND LENGTH(TRIM(barcode)) >= 6;
""")

batch = []
total_inserted = 0

while True:
  rows = cur_master.fetchmany(100000)
  if not rows:
    break

  for barcode, title, artist, year, image_path in rows:
    clean_barcode = str(barcode).strip().replace(" ", "").replace("-", "")
    clean_title = title if title else "Unknown Title"
    clean_artist = artist if artist else "Unknown Artist"
    clean_year = str(year) if year and str(year) != "0" else "N/D"
    clean_cover = (
        image_path if image_path and str(image_path).strip() != "" else None
    )

    batch.append((
        clean_barcode,
        clean_title,
        clean_artist,
        "Rock",
        clean_year,
        clean_cover,
    ))

  # Inserimento a blocchi ignorando eventuali duplicati di barcode
  cur_out.executemany(
      "INSERT OR IGNORE INTO vinyls VALUES (?, ?, ?, ?, ?, ?)", batch
  )
  conn_out.commit()
  total_inserted += len(batch)
  print(f"-> Inseriti {total_inserted:,} vinili...", end="\r")
  batch.clear()

print(f"\nTotale vinili inseriti nel DB dell'app: {total_inserted:,}")

# 3. Creazione degli indici B-Tree per ricerche a tempo zero
print("Creazione indice barcode per scanner istantaneo...")
cur_out.execute("CREATE INDEX idx_barcode ON vinyls(barcode);")

print("Creazione indice per la ricerca manuale (titolo/artista)...")
cur_out.execute("CREATE INDEX idx_search ON vinyls(artist, title);")

# 4. Compattazione finale
print("Compattazione e ottimizzazione file SQLite (VACUUM)...")
cur_out.execute("VACUUM;")
conn_out.close()
conn_master.close()

# Crea copia anche sul Desktop
if os.path.exists(xcode_db):
  import shutil

  shutil.copy2(xcode_db, desktop_db)
  size_mb = os.path.getsize(xcode_db) / (1024 * 1024)
  elapsed = time.time() - start_time
  print(
      f"\n🎉 SUCCESSO! Database generato in {elapsed:.1f}s: {size_mb:.2f} MB"
      f" con {total_inserted:,} vinili totali!"
  )
  print(f"Posizione: {xcode_db}")