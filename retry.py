import os
import shutil
import sqlite3
import time

master_db = os.path.expanduser("~/Desktop/discogs_vinyls.db")
xcode_db = (
    "/Users/francescacoppola/Desktop/Academy Stuff/VinillyApp/vinilly_offline.db"
)
desktop_db = os.path.expanduser("~/Desktop/vinilly_offline.db")

print("1/4 - Connessione a discogs_vinyls.db...")
conn_master = sqlite3.connect(master_db)
cur_master = conn_master.cursor()

# Controllo se l'indice esiste già per non perdere tempo
print(
    "2/4 - Ottimizzazione lettura (creazione indice su barcode se mancante)..."
)
t0 = time.time()
cur_master.execute(
    "CREATE INDEX IF NOT EXISTS idx_master_barcode ON"
    " vinyl_releases(barcode);"
)
conn_master.commit()
print(f"      Indice pronto in {time.time() - t0:.1f}s.")

# Rimuovi file vecchi
for p in [xcode_db, desktop_db]:
  if os.path.exists(p):
    try:
      os.remove(p)
    except Exception:
      pass

print("3/4 - Creazione nuovo vinilly_offline.db...")
conn_out = sqlite3.connect(desktop_db)
cur_out = conn_out.cursor()

# Flag di accelerazione estrema per scrittura SQLite
cur_out.execute("PRAGMA journal_mode = OFF;")
cur_out.execute("PRAGMA synchronous = 0;")
cur_out.execute("PRAGMA cache_size = 200000;")

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
conn_out.commit()

print("      Estrazione e scrittura di tutti i vinili...")
start_export = time.time()

# Query indicizzata: estrae solo i record con barcode valido
query = """
    SELECT barcode, title, artist, year, image_path 
    FROM vinyl_releases 
    WHERE barcode IS NOT NULL 
      AND barcode != '' 
      AND barcode != '\\N'
      AND LENGTH(TRIM(barcode)) >= 6;
"""

cur_master.execute(query)

batch = []
total = 0

while True:
  rows = cur_master.fetchmany(50000)
  if not rows:
    break

  for b, t, a, y, img in rows:
    clean_b = str(b).strip().replace(" ", "").replace("-", "")
    if len(clean_b) < 6:
      continue
    clean_t = str(t).strip() if t else "Unknown Title"
    clean_a = str(a).strip() if a else "Unknown Artist"
    clean_y = str(y).strip() if y and str(y) != "0" else "N/D"
    clean_cover = str(img).strip() if img and str(img).strip() != "" else None

    batch.append((clean_b, clean_t, clean_a, "Rock", clean_y, clean_cover))

  cur_out.executemany(
      "INSERT OR IGNORE INTO vinyls VALUES (?, ?, ?, ?, ?, ?)", batch
  )
  conn_out.commit()
  total += len(batch)
  print(f"      -> Inseriti {total:,} vinili...", end="\r")
  batch.clear()

print(f"\n      Totale vinili trasferiti: {total:,}")

print("4/4 - Creazione indici di ricerca B-Tree per iOS...")
cur_out.execute("CREATE INDEX idx_app_barcode ON vinyls(barcode);")
cur_out.execute("CREATE INDEX idx_app_search ON vinyls(artist, title);")
conn_out.commit()

cur_out.execute("VACUUM;")
conn_out.close()
conn_master.close()

# Copia diretta dentro Xcode
if os.path.exists(desktop_db):
  shutil.copy2(desktop_db, xcode_db)
  size_mb = os.path.getsize(xcode_db) / (1024 * 1024)
  elapsed = time.time() - start_export
  print(f"\n🎉 SUCCESSO TOTALE in {elapsed:.1f}s!")
  print(f"File database: {size_mb:.2f} MB con {total:,} vinili.")
  print(f"Copiato direttamente in: {xcode_db}")