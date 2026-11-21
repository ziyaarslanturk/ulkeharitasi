#!/usr/bin/env bash
# Kullanım: bash tools/uret.sh <bolge-id>
# Geofabrik'ten ülke dosyasını indirir, Mapsforge .map üretir, Release'e yükler.
set -euo pipefail

ID="$1"
ROOT="$(pwd)"
REPO="${GITHUB_REPOSITORY:-ziyaarslanturk/ulkeharitasi}"
TAG="haritalar"
LIMIT=$((1900 * 1024 * 1024))     # GitHub dosya sınırı 2 GB, güvenli pay

AD=$(jq -r --arg id "$ID" '.[]|select(.id==$id)|.ad' bolgeler.json)
GF=$(jq -r --arg id "$ID" '.[]|select(.id==$id)|.geofabrik' bolgeler.json)
[ -n "$GF" ] && [ "$GF" != "null" ] || { echo "Bölge yok: $ID"; exit 1; }

mkdir -p calisma meta
cd calisma

# ---------- Osmosis ----------
OSMOSIS=""
for ver in 0.49.2 0.48.3; do
  url="https://github.com/openstreetmap/osmosis/releases/download/${ver}/osmosis-${ver}.tgz"
  echo "== Osmosis deneniyor: $url"
  if curl -fL --retry 3 -o osmosis.tgz "$url"; then
    mkdir -p osmosis && tar xzf osmosis.tgz -C osmosis
    OSMOSIS=$(find osmosis -type f -path '*/bin/osmosis' | head -1 || true)
    [ -n "$OSMOSIS" ] && { chmod +x "$OSMOSIS"; break; }
  fi
done
if [ -z "$OSMOSIS" ]; then
  echo "== GitHub indirmesi olmadı, apt ile kuruluyor"
  sudo apt-get update -qq
  sudo apt-get install -y -qq osmosis
  OSMOSIS="osmosis"
fi
echo "== Osmosis: $OSMOSIS"

# ---------- Mapsforge harita yazma eklentisi ----------
mkdir -p "$HOME/.openstreetmap/osmosis/plugins"
PLUGIN="$HOME/.openstreetmap/osmosis/plugins/mapsforge-map-writer.jar"
ok=0
for ver in 0.21.0 0.20.0 0.19.0; do
  url="https://repo1.maven.org/maven2/org/mapsforge/mapsforge-map-writer/${ver}/mapsforge-map-writer-${ver}-jar-with-dependencies.jar"
  echo "== Eklenti deneniyor: $url"
  if curl -fL --retry 3 -o "$PLUGIN" "$url"; then ok=1; break; fi
done
[ "$ok" = 1 ] || { echo "HATA: Mapsforge eklentisi indirilemedi"; exit 1; }

# ---------- Veri ----------
echo "== $AD verisi indiriliyor (Geofabrik)"
curl -fL --retry 5 -o "${ID}.osm.pbf" "https://download.geofabrik.de/${GF}-latest.osm.pbf"
ls -lh "${ID}.osm.pbf"

# ---------- .map üretimi ----------
echo "== .map üretiliyor"
export JAVACMD_OPTIONS="-Xmx6g"
"$OSMOSIS" \
  --rb file="${ID}.osm.pbf" \
  --mapfile-writer file="${ID}.map" \
  type=hd \
  zoom-interval-conf=5,0,7,10,8,11,14,12,21 \
  threads=2 \
  label-position=true \
  polygon-clipping=true \
  way-clipping=true \
  preferred-languages=tr,en \
  comment="OpenStreetMap katilimcilari (ODbL) - ${AD}"

BOYUT=$(stat -c %s "${ID}.map")
echo "== Üretilen boyut: $BOYUT bayt"
if [ "$BOYUT" -gt "$LIMIT" ]; then
  echo "HATA: ${ID}.map 1,9 GB üstünde. Bölgeyi bolgeler.json içinde alt bölgelere bölün."
  exit 1
fi

SHA=$(sha256sum "${ID}.map" | cut -d' ' -f1)

echo "== Release'e yükleniyor"
gh release upload "$TAG" "${ID}.map" --clobber --repo "$REPO"

jq -n \
  --arg id "$ID" --arg ad "$AD" --arg dosya "${ID}.map" \
  --argjson boyut "$BOYUT" --arg sha "$SHA" \
  --arg url "https://github.com/${REPO}/releases/download/${TAG}/${ID}.map" \
  --arg t "$(date -u +%FT%TZ)" \
  '{id:$id, ad:$ad, dosya:$dosya, boyut:$boyut, sha256:$sha, url:$url, guncelleme:$t}' \
  > "${ROOT}/meta/${ID}.json"

rm -f "${ID}.osm.pbf"
echo "== Bitti: $ID"
