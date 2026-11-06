#!/bin/bash
# usage: kenney.sh <slug> <outdir>
slug=$1; out=$2; jar=$(mktemp)
page=$(curl -s -m 20 -c $jar -b $jar https://kenney.nl/assets/$slug)
id=$(echo "$page" | grep -oE "data-download-id='[0-9a-f]+'" | head -1 | cut -d"'" -f2)
resp=$(curl -s -m 20 -c $jar -b $jar -H "Referer: https://kenney.nl/assets/$slug" https://kenney.nl/download-link/$id)
url=$(echo "$resp" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('url') or d.get('link') or d)")
curl -s -m 200 -L -o $out/$slug.zip "$url" && mkdir -p $out/$slug && unzip -q -o $out/$slug.zip -d $out/$slug && echo "$slug OK $(du -sh $out/$slug | cut -f1)"
