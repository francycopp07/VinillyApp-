import os
import sqlite3

rg_cover_tsv = os.path.expanduser(
    "~/Downloads/mbdump/cover_art_archive.release_group_cover_art"
)
release_group_tsv = os.path.expanduser("~/Downloads/mbdump/release_group")
release_tsv = os.path.expanduser("~/Downloads/mbdump/release")
app_db = os.path.expanduser("~/Desktop/vinilly_offline.db")

conn = sqlite3.connect(app_db)
cur = conn.cursor()
cur.execute("PRAGMA journal_mode = WAL;")
cur.execute("PRAGMA synchronous = NORMAL;")

# 1. Carichiamo in un set gli ID numerici dei Release Group che hanno davvero una copertina
print("1/4 - Lettura Release Groups con copertina verificata...")
rg_with_art = set()
if os.path.exists(rg_cover_tsv):
  with open(rg_cover_tsv, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
      parts = line.rstrip("\n").split("\t")
      if len(parts) >= 2:
        try:
          rg_with_art.add(int(parts[1]))
        except ValueError:
          continue
  print(f"      Trovati {len(rg_with_art):,} Release Groups con cover.")
else:
  print(
      f"⚠️ File {rg_cover_tsv} non trovato! Verifica l'estrazione da"
      " mbdump-cover-art-archive."
  )
  exit(1)

# 2. Mappiamo release_group_id numerico -> UUID a 36 caratteri
print("2/4 - Mappatura release_group_id -> UUID...")
rg_id_to_uuid = {}
with open(release_group_tsv, "r", encoding="utf-8", errors="replace") as f:
  for line in f:
    parts = line.rstrip("\n").split("\t")
    if len(parts) >= 2:
      try:
        rg_id = int(parts[0])
        if rg_id in rg_with_art:
          rg_uuid = parts[1].strip()
          if len(rg_uuid) == 36:
            rg_id_to_uuid[rg_id] = rg_uuid
      except ValueError:
        continue
print(f"      Mappati {len(rg_id_to_uuid):,} UUID di Release Groups con cover.")

# 3. Leggiamo mbdump/release per mappare i barcode ai Release Groups
print("3/4 - Incrocio Barcode con Release Groups...")
cur.execute("DROP TABLE IF EXISTS barcode_rg_cover;")
cur.execute(
    "CREATE TABLE barcode_rg_cover (barcode TEXT PRIMARY KEY, image_url TEXT);"
)
conn.commit()

batch = []
count = 0
with open(release_tsv, "r", encoding="utf-8", errors="replace") as f:
  for line in f:
    parts = line.rstrip("\n").split("\t")
    # parts[4] = release_group_id, parts[9] = barcode
    if len(parts) >= 10:
      try:
        raw_barcode = parts[9].strip().replace(" ", "").replace("-", "")
        if len(raw_barcode) >= 6 and raw_barcode != "\\N":
          rg_id = int(parts[4])
          if rg_id in rg_id_to_uuid:
            rg_uuid = rg_id_to_uuid[rg_id]
            # Endpoint ufficiale CAA per Release Group
            url = f"https://coverartarchive.org/release-group/{rg_uuid}/front-500"
            batch.append((raw_barcode, url))
      except (ValueError, IndexError):
        continue

      if len(batch) >= 50000:
        cur.executemany(
            "INSERT OR IGNORE INTO barcode_rg_cover VALUES (?, ?)", batch
        )
        conn.commit()
        count += len(batch)
        print(f"      Barcode associati a Release Groups: {count:,}...", end="\r")
        batch.clear()

if batch:
  cur.executemany("INSERT OR IGNORE INTO barcode_rg_cover VALUES (?, ?)", batch)
  conn.commit()
  count += len(batch)

print(f"\n      Totale collegamenti barcode -> Release Group cover: {count:,}")

# 4. Aggiorniamo i vinili privi di copertina
print("4/4 - Riempimento copertine mancanti in vinilly_offline.db...")
cur.execute("""
UPDATE vinyls
SET coverUrl = (
    SELECT b.image_url 
    FROM barcode_rg_cover b 
    WHERE b.barcode = vinyls.barcode
)
WHERE coverUrl IS NULL;
""")
conn.commit()

cur.execute("SELECT COUNT(*) FROM vinyls WHERE coverUrl IS NOT NULL;")
tot_con_cover = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM vinyls;")
tot_generale = cur.fetchone()[0]

print(
    f"\n🎉 AGGIORNAMENTO COMPLETATO: {tot_con_cover:,} su {tot_generale:,} vinili"
    " ora hanno una copertina!"
)

cur.execute("DROP TABLE IF EXISTS barcode_rg_cover;")
cur.execute("VACUUM;")
conn.close()