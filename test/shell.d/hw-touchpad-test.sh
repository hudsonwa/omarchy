#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"

# hyprctl is stubbed with a fixed devices listing. Names come straight from
# real hyprctl output shapes: touchpads appear under .mice with controller
# names (synaptics-tm3096-006, elan...-touchpad), while touchscreens live in
# .touch and must not be picked up by the touchpad detector.
cat >"$tmp_dir/bin/hyprctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$HYPRCTL_DEVICES_JSON"
EOF
chmod +x "$tmp_dir/bin/hyprctl"

hw_touchpad() {
  PATH="$tmp_dir/bin:$PATH" HYPRCTL_DEVICES_JSON="$1" "$ROOT/bin/omarchy-hw-touchpad"
}

assert_detects() {
  local description=$1 json=$2
  local device

  # omarchy-hw-touchpad exits 1 on no device; keep set -e from killing the
  # capture so the assertion below can report it as a proper failure.
  device=$(hw_touchpad "$json" || true)
  [[ -n $device ]] || fail "$description" "no device detected"
  pass "$description"
}

assert_rejects() {
  local description=$1 json=$2

  if [[ -n $(hw_touchpad "$json" || true) ]]; then
    fail "$description"
  fi
  pass "$description"
}

# The reporter's hardware: a Synaptics touchpad that names itself only by
# controller, with no literal "touchpad"/"trackpad" word.
assert_detects "a touchpad named only by its controller is detected" \
  '{"mice":[{"name":"synaptics-tm3096-006"}],"touch":[]}'

assert_detects "the existing literal-name match still works" \
  '{"mice":[{"name":"elan0501:00 04f3:31fa Touchpad"}],"touch":[]}'

assert_detects "an ALPS touchpad is detected" \
  '{"mice":[{"name":"ALPS0001:00 03e8:1055 Touchpad"}],"touch":[]}'

# A touchscreen in .touch is not a touchpad, even when the vendor name would
# match: .touch belongs to the touchscreen detector.
assert_rejects "a touchscreen in .touch is not detected as a touchpad" \
  '{"mice":[],"touch":[{"name":"ELAN Touchscreen"}]}'

assert_rejects "a plain mouse is not detected" \
  '{"mice":[{"name":"SINO WEALTH Gaming Mouse"}],"touch":[]}'

pass "omarchy-hw-touchpad detects touchpads by name or controller, never touchscreens"
