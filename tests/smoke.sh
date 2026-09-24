#!/usr/bin/env bash
# Smoke tests for bin/macos-keyboard-layout against a stubbed hyprctl.
# The real xkbcli catalog is used for validation.
set -euo pipefail

cd "$(dirname "$0")/.."
HELPER="$PWD/bin/macos-keyboard-layout"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
export XDG_STATE_HOME="$WORK/state"
STATE="$WORK/state/omarchy/settings/smyrnode-macos-keyboard-toggle.json"
TOGGLE="$WORK/state/omarchy/toggles/hypr/smyrnode-macos-keyboard-toggle.lua"
export PATH="$WORK/bin:$PATH"
export STUB_LOG="$WORK/hyprctl.log"

cat >"$WORK/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_LOG:-/dev/null}"
case "${1:-}" in
  -j)
    case "${2:-}" in
      devices)
        printf '%s\n' '{"keyboards":[{"name":"test-kbd","active_layout_index":0,"active_keymap":"English (US)","layout":"us,ru"},{"name":"test-kbd-1","active_layout_index":0,"active_keymap":"English (US)","layout":"us,ru"},{"name":"power-button","active_layout_index":0,"active_keymap":"English (US)","layout":"us,ru"}]}'
        ;;
      getoption)
        case "${3:-}" in
          input:kb_layout) printf '%s\n' '{"str":"us,ru"}' ;;
          input:kb_variant) printf '%s\n' '{"str":""}' ;;
          input:kb_options) printf '%s\n' '{"str":"compose:caps"}' ;;
          misc:disable_autoreload) printf '%s\n' '{"bool":false}' ;;
          *) printf '%s\n' '{"str":""}' ;;
        esac ;;
    esac ;;
  eval) printf 'ok\n' ;;
  switchxkblayout) printf 'ok\n' ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/hyprctl"

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok: $1"; }

# 1. first status snapshots the stub session (us,ru; compose:caps; mode mru)
out=$("$HELPER" status) || fail "status should succeed"
jq -e '.switchMode == "mru" and (.layouts | length) == 2 and .layouts[0].layout == "us"' <<<"$out" >/dev/null \
  || fail "snapshot should import us,ru in mru mode"
grep -q 'kb_layout = "us,ru"' "$TOGGLE" || fail "toggle should list us,ru"
grep -q 'kb_options = "compose:caps"' "$TOGGLE" || fail "mru mode must not add a grp option"
grep -q 'grp:' "$TOGGLE" && fail "mru toggle must contain no grp option"
pass "snapshot + mru toggle"

# 2. add a language
out=$("$HELPER" add fr) || fail "add fr should succeed"
jq -e '(.layouts | length) == 3 and .layouts[2].layout == "fr"' <<<"$out" >/dev/null || fail "fr should be appended"
grep -q 'kb_layout = "us,ru,fr"' "$TOGGLE" || fail "toggle should list us,ru,fr"
pass "add fr"

# 3. duplicate add is refused
if "$HELPER" add fr >/dev/null 2>&1; then fail "duplicate add should fail"; fi
pass "duplicate add refused"

# 4. xkb mode brings the group shortcut into the keymap
out=$("$HELPER" mode xkb) || fail "mode xkb should succeed"
grep -q 'grp:ctrl_space_toggle' "$TOGGLE" || fail "xkb mode should enable the group shortcut"
pass "mode xkb enables shortcut"

# 5. mru mode takes it back out
out=$("$HELPER" mode mru) || fail "mode mru should succeed"
grep -q 'grp:' "$TOGGLE" && fail "mru mode should drop the group shortcut"
pass "mru mode drops shortcut"

# 6. removing the only leading Latin layout is refused
if "$HELPER" remove 0 >/dev/null 2>&1; then fail "removing us (latin-first) should fail"; fi
pass "latin-first guard"

# 7. removing a middle layout works
out=$("$HELPER" remove 1) || fail "remove 1 should succeed"
jq -e '(.layouts | length) == 2 and .layouts[0].layout == "us" and .layouts[1].layout == "fr"' <<<"$out" >/dev/null \
  || fail "ru should be removed"
pass "remove ru"

# 8. alias is metadata-only (keymap untouched)
cp "$TOGGLE" "$WORK/toggle.before"
out=$("$HELPER" alias 0 Work) || fail "alias should succeed"
jq -e '.layouts[0].alias == "Work"' <<<"$out" >/dev/null || fail "alias should be stored"
cmp -s "$WORK/toggle.before" "$TOGGLE" || fail "alias must not regenerate the keymap"
if "$HELPER" alias 0 "toolong1" >/dev/null 2>&1; then fail "long alias should fail"; fi
pass "alias metadata-only"

# 9. shortcut change in mru mode updates state only
cp "$TOGGLE" "$WORK/toggle.before"
: >"$STUB_LOG"
out=$("$HELPER" shortcut grp:alts_toggle) || fail "shortcut should succeed"
jq -e '.switchOption == "grp:alts_toggle"' <<<"$out" >/dev/null || fail "shortcut should be stored"
cmp -s "$WORK/toggle.before" "$TOGGLE" || fail "shortcut in mru mode must not reapply the keymap"
grep -q 'eval' "$STUB_LOG" && fail "shortcut in mru mode must not hit hyprctl eval"
pass "shortcut in mru mode is metadata-only"

# 10. the stored shortcut is what xkb mode enables
"$HELPER" mode xkb >/dev/null || fail "mode xkb should succeed"
grep -q 'grp:alts_toggle' "$TOGGLE" || fail "xkb mode should enable the chosen shortcut"
pass "xkb mode uses chosen shortcut"

# 11. invalid shortcut is refused
if "$HELPER" shortcut grp:bogus_option >/dev/null 2>&1; then fail "bogus shortcut should fail"; fi
pass "invalid shortcut refused"

echo "ALL TESTS PASSED"
