# ulkeharitasi

Trailo PRO için çevrimdışı harita dosyaları. Dosyalar **Mapsforge `.map`** (vektör) biçimindedir,
GitHub Actions ile Geofabrik'in ülke dosyalarından üretilir ve **Releases > haritalar** altına yüklenir.

Uygulama şu listeyi okur:

    https://raw.githubusercontent.com/ziyaarslanturk/ulkeharitasi/main/regions.json

Her kayıtta: `id`, `ad`, `dosya`, `boyut` (bayt), `sha256`, `url`, `guncelleme`.

## Çalıştırma
1. Actions sekmesi > **Harita üret** > **Run workflow**.
2. `ulke` alanına `turkey` yaz (veya `hepsi`).
3. İş bitince `regions.json` otomatik güncellenir. Her ayın 1'inde kendiliğinden yenilenir.

## Bölge ekleme
`bolgeler.json` dosyasına satır ekle:

    { "id": "germany", "ad": "Almanya", "geofabrik": "europe/germany" }

`geofabrik` değeri, `https://download.geofabrik.de/` adresindeki yoldur (sonundaki `-latest.osm.pbf` hariç).
Büyük ülkeleri alt bölgelere böl (ör. `north-america/us/california`). Her dosya 1,9 GB altında kalmalı.

## Lisans
Harita verisi (c) OpenStreetMap katılımcıları, ODbL 1.0.
