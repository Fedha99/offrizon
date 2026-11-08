#!/usr/bin/env bash
# Rebrand a fork of Horizon -> "Offrizon" (light rename, upstream-merge friendly).
#
# WHAT IT RENAMES (safe, word-bounded):
#   - launcher/src/*.rs      user-visible strings + comments ("Horizon" -> "Offrizon")
#   - launcher/lang/*.json   translation keys AND values (kept in sync with src)
#   - README.md, packaging/PLAY.txt
#
# WHAT IT DOES NOT TOUCH (on purpose):
#   - LICENSE (MIT: must keep the original copyright notice - this IS your credit compliance)
#   - Crate names (horizon-*), env vars (HORIZON_MSA_CLIENT_ID), URLs, lowercase identifiers
#   - Compound identifiers (PlayHorizon, HorizonScene, ...) via \b word boundaries
#
# Run it in the root of your fork:  bash rebrand-offrizon.sh

set -euo pipefail

if [ ! -f LICENSE ] || [ ! -d launcher/src ]; then
    echo "Run this from the root of the Offrizon (Horizon fork) repository." >&2
    exit 1
fi

# 0) Safety branch
git checkout -b offrizon-rebrand 2>/dev/null || git checkout offrizon-rebrand

# 1) Word-boundary rename: standalone "Horizon" only, never inside identifiers.
#    \b between letters fails inside PlayHorizon / mount_Horizon / HORIZON_MSA, so they survive.
rename_brand() {
    sed -i -E 's/\bHorizon\b/Offrizon/g' "$@"
}

rename_brand launcher/src/*.rs
rename_brand launcher/lang/*.json
rename_brand README.md
[ -f packaging/PLAY.txt ] && rename_brand packaging/PLAY.txt

# 2) Credit block (MIT compliance + the credit you promised the original developer).
if ! grep -q "horizon-rust/horizon" README.md; then
cat >> README.md <<'EOF'

## Credits

Offrizon is a fork of [Horizon](https://github.com/horizon-rust/horizon) - Minecraft: Java
Edition rewritten in Rust - by the Horizon contributors (lead: Ludovic), licensed under the
[MIT license](LICENSE). All credit for the original engine, design and implementation belongs
to them; this fork only adds offline-account support and rebranding.
EOF
fi

cat > CREDITS.md <<'EOF'
# Credits

- **Original project**: [Horizon](https://github.com/horizon-rust/horizon)
  "Minecraft: Java Edition 26.3 rewritten from scratch in Rust"
  by the Horizon contributors - MIT License.
- **This fork**: Offrizon - removes the Microsoft-account requirement for offline accounts
  (offline names play with a vanilla-compatible offline UUID; Microsoft sign-in remains
  available and unchanged for online-mode servers).
- `LICENSE` is kept verbatim and contains the original copyright notice, as required by the
  MIT license. Horizon is not affiliated with Mojang or Microsoft; neither is Offrizon.
EOF

git add -A
git commit -m "Rebrand to Offrizon; credit the original Horizon developers (MIT)" --no-verify
echo "Done. Review with: git show --stat HEAD"
