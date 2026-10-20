import os
import re
import sqlite3
import unicodedata

app_db = (
    "/Users/francescacoppola/Desktop/Academy Stuff/VinillyApp/vinilly_offline.db"
)
mb_release_tsv = os.path.expanduser("~/Downloads/mbdump/release")
mb_artist_credit_tsv = os.path.expanduser(
    "~/Downloads/mbdump/artist_credit"
)  # se disponibile, altrimenti usiamo release_group
caa_tsv = os.path.expanduser("~/Downloads/mbdump/cover_art_archive.index_listing")


def normalize_key(artist: str, title: str) -> str:
  # Rimuove accenti, punteggiatura e porta tutto in minuscolo
  text = f"{artist} {title}".lower()
  text = unicodedata.normalize("NFKD", text).encode("ASCII", "ignore").decode()
  text = re.sub(r"[^a-z0-9]", "", text)
  return text


conn = sqlite3.connect(app_db)
cur = conn.cursor()

# Creiamo la tabella di lookup per nome
cur.execute("""
CREATE TABLE IF NOT EXISTS album_covers (
    lookup_key TEXT PRIMARY KEY,
    cover_url TEXT
);
""")
cur.execute(
    "CREATE INDEX IF NOT EXISTS idx_cover_lookup ON album_covers(lookup_key);"
)
conn.commit()

# Popoliamo anche direttamente i vinili esistenti che hanno già una coverUrl
print("Indicizzazione copertine già presenti nel database...")
cur.execute(
    "SELECT artist, title, coverUrl FROM vinyls WHERE coverUrl IS NOT NULL;"
)
existing_covers = []
for artist, title, url in cur.fetchall():
  key = normalize_key(artist, title)
  if key and url:
    existing_covers.append((key, url))

cur.executemany(
    "INSERT OR IGNORE INTO album_covers VALUES (?, ?)", existing_covers
)
conn.commit()
print(f"Inserite {len(existing_covers):,} copertine note nella mappa.")

# Ora aggiorniamo i vinili che hanno coverUrl NULL cercando corrispondenza per titolo/artista
print("Assegnazione copertine ai vinili privi di immagine...")
cur.execute("""
UPDATE vinyls
SET coverUrl = (
    SELECT ac.cover_url 
    FROM album_covers ac 
    WHERE ac.lookup_key = (
        -- funzione semplificata di matching
        LOWER(REPLACE(REPLACE(vinyls.artist || vinyls.title, ' ', ''), '-', ''))
    )
)
WHERE coverUrl IS NULL;
""")
conn.commit()

cur.execute("SELECT COUNT(*) FROM vinyls WHERE coverUrl IS NOT NULL;")
tot = cur.fetchone()[0]
print(f"🎉 Totale vinili ora coperti da immagine: {tot:,}")

cur.execute("VACUUM;")
conn.close()