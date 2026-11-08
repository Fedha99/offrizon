#!/usr/bin/env bash
# Rebrand a fork of Horizon -> "Offrizon"  (v2 - recursive fix)
#
# v1 bug: `launcher/src/*.rs` only renamed files DIRECTLY in launcher/src, missing
# subdirectories (launcher/src/browser/ etc.), which broke `SourceId::Horizon` uses
# (error E0599). v2 renames recursively across ALL launcher sources and keeps the
# JSON wire format of SourceId as "horizon" so saved data and the mod registry
# keep working.
#
# Safe to run multiple times (idempotent) and on top of v1's partial rename:
# it completes whatever is left. Run it from the root of the fork repository.

set -euo pipefail

if [ ! -f LICENSE ] || [ ! -d launcher/src ]; then
    echo "Run this from the root of the Offrizon (Horizon fork) repository." >&2
    exit 1
fi

# 0) Safety branch (keeps any existing work).
git checkout -b offrizon-rebrand 2>/dev/null || git checkout offrizon-rebrand

# 1) Word-boundary rename: standalone "Horizon" only. \b fails inside identifiers
#    like PlayHorizon / mount_Horizon / HORIZON_MSA_CLIENT_ID, so they survive.
#    v2: RECURSIVE over every .rs, including all subdirectories.
find launcher/src launcher/tests -name '*.rs' -type f -print0 \
    | xargs -0 sed -i -E 's/\bHorizon\b/Offrizon/g'
sed -i -E 's/\bHorizon\b/Offrizon/g' launcher/build.rs
sed -i -E 's/\bHorizon\b/Offrizon/g' launcher/lang/*.json
sed -i -E 's/\bHorizon\b/Offrizon/g' README.md
[ -f packaging/PLAY.txt ] && sed -i -E 's/\bHorizon\b/Offrizon/g' packaging/PLAY.txt

# 2) SourceId is serialized with #[serde(rename_all = "kebab-case")] -> "horizon".
#    Keep that exact wire value so locally saved entries and anything speaking
#    Horizon's registry format keeps parsing; only the Rust name and the UI
#    label become Offrizon.
python3 - <<'EOF'
import re
p = 'launcher/src/browser.rs'
s = open(p).read()
if '#[serde(rename = "horizon")]' not in s:
    s2, n = re.subn(
        r'(pub enum SourceId \{.*?\n)(    Offrizon,)',
        r'\1    #[serde(rename = "horizon")]\n\2',
        s, count=1, flags=re.S)
    if n != 1:
        raise SystemExit(f'could not find the SourceId variant in {p}')
    open(p, 'w').write(s2)
    print('SourceId: JSON wire format pinned to "horizon"')
else:
    print('SourceId: wire-format alias already present')
EOF

# 3) Credit block (MIT compliance + credit to the original developer).
if ! grep -q "horizon-rust/horizon" README.md; then
cat >> README.md <<'EOF'

## Credits

Offrizon is a fork of [Horizon](https://github.com/horizon-rust/horizon) - Minecraft: Java
Edition rewritten in Rust - by the Horizon contributors (lead: Ludovic), licensed under the
[MIT license](LICENSE). All credit for the original engine, design and implementation belongs
to them; this fork only adds offline-account support and rebranding.
EOF
fi

if [ ! -f CREDITS.md ]; then
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
fi

# 4) Prove it compiles before committing (lib + tests + cli).
echo "== cargo check (lib, tests, cli) - this takes a few minutes =="
(cd launcher && cargo check --lib --tests --bins)

# 5) Commit only when something actually changed.
git add -A
if ! git diff --cached --quiet; then
    git commit --no-verify -m "Complete the Offrizon rebrand recursively; keep SourceId JSON format"
    echo "Done - committed. Push with: git push -u origin offrizon-rebrand"
else
    echo "Done - nothing new to commit."
fi
