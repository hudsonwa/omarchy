#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -r "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"
mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d"

# 1) Executable non-bash hook. omarchy-hook used to force every file in a
#    .d directory through `bash`, which mangles Python/other shebang
#    scripts. An executable file must be run directly so its shebang picks
#    the interpreter.
cat >"$HOME/.config/omarchy/hooks/theme-set.d/notify.py" <<'EOF'
#!/usr/bin/env python3
import sys
print("python hook ran: " + " ".join(sys.argv[1:]))
EOF
chmod +x "$HOME/.config/omarchy/hooks/theme-set.d/notify.py"

# 2) Non-executable bash hook. The shipped samples are not executable, so
#    the bash fallback has to keep working for them.
cat >"$HOME/.config/omarchy/hooks/theme-set.d/notify.bash" <<'EOF'
#!/bin/bash
echo "bash hook ran: $1"
EOF

# 3) A .sample file must stay skipped.
cat >"$HOME/.config/omarchy/hooks/theme-set.d/ignored.sample" <<'EOF'
#!/bin/bash
echo "sample must not run"
EOF

# 4) Flat named hook (hooks/<name>, no .d dir): same rule applies.
cat >"$HOME/.config/omarchy/hooks/theme-set" <<'EOF'
#!/bin/bash
echo "flat hook ran: $1"
EOF
chmod +x "$HOME/.config/omarchy/hooks/theme-set"

out=$("$ROOT/bin/omarchy-hook" theme-set mytheme)
printf '%s\n' "$out" >"$tmp_dir/out"

grep -q "python hook ran: mytheme" "$tmp_dir/out" ||
  fail "executable non-bash hook runs through its own shebang" "$out"
grep -q "bash hook ran: mytheme" "$tmp_dir/out" ||
  fail "non-executable hook still falls back to bash" "$out"
grep -q "sample must not run" "$tmp_dir/out" &&
  fail ".sample hooks are skipped" "$out"
grep -q "flat hook ran: mytheme" "$tmp_dir/out" ||
  fail "executable flat hook runs through its own shebang" "$out"

pass "executable hooks use their shebang, non-executable hooks use bash"
