#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi

OUTPUT_DIRECTORY="$1"
WORK_DIRECTORY="$(mktemp -d /private/tmp/SandboxLens-acquire.XXXXXX)"
MACOS_REPORTS_COMMIT="e91132f209ae756b0036f1bfbff9effaf9386b82"

cleanup() {
  rm -rf "$WORK_DIRECTORY"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIRECTORY"

git clone --quiet https://github.com/knightsc/sandbox_profiles.git "$WORK_DIRECTORY/knightsc"

while IFS='|' read -r product_version build_version commit_hash release_channel; do
  release_id="macos-${product_version}-${build_version}"
  release_directory="$OUTPUT_DIRECTORY/$release_id"
  if [[ -e "$release_directory" ]]; then
    echo "refusing to merge into existing release directory: $release_directory" >&2
    exit 1
  fi
  mkdir -p "$release_directory"

  git -C "$WORK_DIRECTORY/knightsc" archive "$commit_hash" \
    usr/share/sandbox System/Library/Sandbox/Profiles 2>/dev/null \
    | tar -x -C "$release_directory"

  cat >"$release_directory/provenance.json" <<JSON
{
  "id": "$release_id",
  "displayName": "macOS $product_version ($build_version)",
  "productVersion": "$product_version",
  "buildVersion": "$build_version",
  "releaseChannel": "$release_channel",
  "sourceName": "knightsc/sandbox_profiles",
  "sourceURL": "https://github.com/knightsc/sandbox_profiles/tree/$commit_hash",
  "sourceCommit": "$commit_hash",
  "confidence": "community-snapshot",
  "notes": "Public snapshot whose directory structure mirrors installed macOS profile locations."
}
JSON
done <<'RELEASES'
10.9.5|13F34|638b32eeb0fcf96ea2310a8073a280c238af1509|stable
10.10.5|14F27|4b9db4bdd15f18a880a73ec64aa686e6242eb8a4|stable
10.11.6|15G31|eec9aecd319703fb3fb3acf2686dee7df3224577|stable
10.12.6|16G29|d7991f8ffd9838387425b5dc416933ac11491959|stable
10.13.6|17G65|2b98ec3a3fd04067e9066571cdaa3fe96cb914aa|stable
10.14-beta-7|18A365a|4caae38e50aa1b78d486eda19488e8bb92beafa8|beta
10.14-beta-8|18A371a|7632aea6920a1b51d45d0dd9b52597e386e685e8|beta
10.14-beta-9|18A377a|bf4a86d230e8e083977798fe9d80d2f8ae59514d|beta
10.14-beta-10|18A384a|0cf76b89ad33c933c35ea979a1d2e499d28552ea|beta
10.14|18A391|a0501d255c6a65427bc6f0c78628a9c37d6c6cf5|stable
10.14.1|18B75|0046728e9f3949ec953592bade1c0320febad2da|stable
10.14.2|18C54|747d9f31a6ab9df1185f51720e1b63a9ee6bb767|stable
10.14.4|18E226|e83bb2575e83964f0f3d37b43f7c902e83812f53|stable
10.14.5|18F132|885dfe272b388de94f242896b7790323a5f7bea3|stable
10.15-beta-1|19A471t|dd69e3ffa7d2f5a1e48cdd0419c4b910687ae813|beta
10.15|19A583|31cb8c9124cbe8dabfec340c4875762073e948ee|stable
10.15.1|19B88|7eed51601f3413041ac533e33fc892748059253b|stable
10.15.2|19C57|9eb25aecbf1e6e77cba64ead53e0dc31ee97c48d|stable
RELEASES

git clone --quiet --filter=blob:none --no-checkout \
  https://github.com/corecryptics/MacOSReports.git "$WORK_DIRECTORY/MacOSReports"
git -C "$WORK_DIRECTORY/MacOSReports" sparse-checkout init --cone
git -C "$WORK_DIRECTORY/MacOSReports" sparse-checkout set Sandbox/Profiles diagnose-fu/sw_vers.txt
git -C "$WORK_DIRECTORY/MacOSReports" checkout --quiet "$MACOS_REPORTS_COMMIT"

monterey_directory="$OUTPUT_DIRECTORY/macos-12.6-21G115"
if [[ -e "$monterey_directory" ]]; then
  echo "refusing to merge into existing release directory: $monterey_directory" >&2
  exit 1
fi
mkdir -p "$monterey_directory/System/Library/Sandbox"
cp -R "$WORK_DIRECTORY/MacOSReports/Sandbox/Profiles" \
  "$monterey_directory/System/Library/Sandbox/Profiles"

cat >"$monterey_directory/provenance.json" <<JSON
{
  "id": "macos-12.6-21G115",
  "displayName": "macOS 12.6 (21G115)",
  "productVersion": "12.6",
  "buildVersion": "21G115",
  "releaseChannel": "stable",
  "sourceName": "corecryptics/MacOSReports",
  "sourceURL": "https://github.com/corecryptics/MacOSReports/tree/$MACOS_REPORTS_COMMIT/Sandbox/Profiles",
  "sourceCommit": "$MACOS_REPORTS_COMMIT",
  "confidence": "community-snapshot-with-build-evidence",
  "notes": "The same repository records ProductVersion 12.6 and BuildVersion 21G115 in diagnose-fu/sw_vers.txt."
}
JSON

echo "Saved public baseline snapshots to $OUTPUT_DIRECTORY"
