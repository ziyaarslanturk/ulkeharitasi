#!/usr/bin/env bash
# Kullanım: bash tools/uret.sh <bolge-id>
# Geofabrik'ten ülke dosyasını indirir, Mapsforge .map üretir, Release'e yükler.
set -euo pipefail

ID="$1"
ROOT="$(pwd)"
REPO="${GITHUB_REPOSITORY:-ziyaarslanturk/ulkeharitasi}"
TAG="haritalar"
LIMIT=$((1900 * 1024 * 1024))     # GitHub dosya sınırı 2 GB, güvenli pay
OSMOSIS_VER="0.49.2"
MAPSFORGE_VER="0.21.0"

AD=$(jq -r --arg id "$ID" '.[]|select(.id==$id)|.ad' bolgeler.json)
GF=$(jq -r --arg id "$ID" '.[]|select(.id==$id)|.geofabrik' bolgeler.json)
[ -n "$GF" ] && [ "$GF" != "null" ] || { echo "Bölge yok: $ID"; exit 1; }

mkdir -p calisma meta
cd calisma

echo "== Osmosis ve Mapsforge eklentisi indiriliyor"
curl -fL --retry 5 -o osmosis.tgz \
  "https://github.com/openstreetmap/osmosis/releases/download/${OSMOSIS_VER}/osmosis-${OSMOSIS_VER}.tgz"
mkdir -p osmosis && tar xzf osmosis.tgz -C osmosis
mkdir -p "$HOME/.openstreetmap/osmosis/plugins"
curl -fL --retry 5 -o "$HOME/.openstreetmap/osmosis/plugins/mapsforge-map-writer.jar" \
  "https://repo1.maven.org/maven2/org/mapsforge/mapsforge-map-writer/${MAPSFORGE_VER}/mapsforge-map-writer-${MAPSFORGE_VER}-jar-with-dependencies.jar"

echo "== $AD verisi indiriliyor (Geofabrik)"
curl -fL --retry 5 -o "${ID}.osm.pbf" "https://download.geofabrik.de/${GF}-latest.osm.pbf"
ls -lh "${ID}.osm.pbf"

echo "== .map üretiliyor"
export JAVACMD_OPTIONS="-Xmx6g"
osmosis/bin/osmosis \
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
