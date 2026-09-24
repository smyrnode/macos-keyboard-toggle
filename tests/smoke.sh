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
          input:kb_options)
            if [[ -n ${STUB_KB_OPTIONS:-} ]]; then
              printf '{"str":"%s"}\n' "$STUB_KB_OPTIONS"
            else
              printf '%s\n' '{"str":"compose:caps"}'
            fi
            ;;
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

cat >"$WORK/bin/fcitx5-remote" <<'EOF'
#!/usr/bin/env bash
printf 'fcitx %s\n' "$*" >>"${STUB_LOG:-/dev/null}"
exit 0
EOF
chmod +x "$WORK/bin/fcitx5-remote"

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

# 4. switching mode is metadata-only: the keymap never gains a grp option
cp "$TOGGLE" "$WORK/toggle.before"
: >"$STUB_LOG"
out=$("$HELPER" mode xkb) || fail "mode xkb should succeed"
jq -e '.switchMode == "xkb" and (has("switchOption") | not)' <<<"$out" >/dev/null || fail "mode xkb should flip the flag without switchOption"
cmp -s "$WORK/toggle.before" "$TOGGLE" || fail "mode change must not regenerate the keymap"
grep -q 'eval' "$STUB_LOG" && fail "mode change must not hit hyprctl eval"
grep -q 'grp:' "$TOGGLE" && fail "keymap must never contain a grp option"
out=$("$HELPER" mode mru) || fail "mode mru should succeed"
jq -e '.switchMode == "mru"' <<<"$out" >/dev/null || fail "mode mru should flip the flag back"
pass "mode is metadata-only"

# 5. the shortcut command is gone: the Switching hotkey owns switching
if "$HELPER" shortcut grp:alts_toggle >/dev/null 2>&1; then fail "shortcut command should be gone"; fi
pass "shortcut command removed"

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

# 9. status reports the live XKB group option (for conflict detection)
out=$("$HELPER" status) || fail "status should succeed"
jq -e '.groupOption == ""' <<<"$out" >/dev/null || fail "groupOption should be empty without a grp option"
out=$(STUB_KB_OPTIONS="compose:caps,grp:ctrl_space_toggle" "$HELPER" status) || fail "status should succeed"
jq -e '.groupOption == "grp:ctrl_space_toggle"' <<<"$out" >/dev/null || fail "groupOption should report the live grp option"
pass "groupOption reported"

# 10. move swaps neighbors
"$HELPER" add gb >/dev/null || fail "add gb should succeed"
out=$("$HELPER" move 0 down) || fail "move down should succeed"
jq -e '.layouts[0].layout == "fr" and .layouts[1].layout == "us" and .layouts[2].layout == "gb"' <<<"$out" >/dev/null || fail "us should swap with fr"
out=$("$HELPER" move 1 up) || fail "move up should succeed"
jq -e '.layouts[0].layout == "us" and .layouts[1].layout == "fr"' <<<"$out" >/dev/null || fail "us should move back to front"
pass "move up/down swaps"

# 11. move at the edges is refused
if "$HELPER" move 0 up >/dev/null 2>&1; then fail "move 0 up should fail"; fi
if "$HELPER" move 2 down >/dev/null 2>&1; then fail "move last down should fail"; fi
pass "move edges refused"

# 12. move cannot put a non-Latin layout first
"$HELPER" add ru >/dev/null || fail "add ru should succeed"  # [us, fr, gb, ru]
"$HELPER" move 3 up >/dev/null || fail "move 3 up should succeed"  # [us, fr, ru, gb]
"$HELPER" move 2 up >/dev/null || fail "move 2 up should succeed"  # [us, ru, fr, gb]
if "$HELPER" move 1 up >/dev/null 2>&1; then fail "non-latin-first move should fail"; fi
pass "move latin-first guard"

# 13. reapply forces a live apply even when nothing changed
: >"$STUB_LOG"
"$HELPER" reapply >/dev/null || fail "reapply should succeed"
grep -q 'eval' "$STUB_LOG" || fail "reapply must hit hyprctl eval"
pass "reapply forces apply"

# 14. hotkey rewrites the binding and records the combo
BINDINGS="$WORK/bindings.lua"
printf '%s\n' '-- keep me' 'o.bind("SUPER + E", "Editor", "nvim")' >"$BINDINGS"
printf '\n-- macOS-style language toggle\n' >>"$BINDINGS"
printf 'o.bind("CTRL + SPACE", "Toggle language (macOS-style)", "~/.local/bin/omarchy-lang-toggle")\n' >>"$BINDINGS"
out=$(SMYRNODE_KB_BINDINGS_FILE="$BINDINGS" "$HELPER" hotkey "super + shift + s") || fail "hotkey should succeed"
jq -e '.hotkey == "SUPER + SHIFT + S"' <<<"$out" >/dev/null || fail "hotkey should be normalized and stored"
grep -q 'o.bind("SUPER + SHIFT + S", "Toggle language (macOS-style)"' "$BINDINGS" || fail "binding should use the new combo"
if grep -q 'CTRL + SPACE' "$BINDINGS"; then fail "old combo should be gone"; fi
grep -q 'SUPER + E' "$BINDINGS" || fail "foreign bindings must survive"
out=$(SMYRNODE_KB_BINDINGS_FILE="$BINDINGS" "$HELPER" status)
jq -e '.hotkey == "SUPER + SHIFT + S"' <<<"$out" >/dev/null || fail "status should report the hotkey"
if SMYRNODE_KB_BINDINGS_FILE="$BINDINGS" "$HELPER" hotkey "JUSTONEKEY" >/dev/null 2>&1; then fail "bare key should fail"; fi
if SMYRNODE_KB_BINDINGS_FILE="$BINDINGS" "$HELPER" hotkey "CTRL + +" >/dev/null 2>&1; then fail "modifier-only combo should fail"; fi
if SMYRNODE_KB_BINDINGS_FILE="$BINDINGS" "$HELPER" hotkey "CTRL + SHIFT" >/dev/null 2>&1; then fail "modifier as key should fail"; fi
cp "$BINDINGS" "$WORK/bindings.once"
SMYRNODE_KB_BINDINGS_FILE="$BINDINGS" "$HELPER" hotkey "SUPER + SHIFT + S" >/dev/null || fail "repeat hotkey should succeed"
cmp -s "$WORK/bindings.once" "$BINDINGS" || fail "hotkey rewrite must be idempotent"
pass "hotkey rewrites binding"

# 15. switching syncs the fcitx5 input method so typing follows
: >"$STUB_LOG"
"$HELPER" set 1 >/dev/null || fail "set should succeed"
grep -q 'fcitx -s keyboard-ru' "$STUB_LOG" || fail "switching must sync the fcitx5 input method"
pass "fcitx5 input method synced"

echo "ALL TESTS PASSED"
