#!/usr/bin/env sh
# Broken Provinces content gate, run from the repository's pre-commit hook.
#
# Fires only when the staged diff touches data/ or scripts/levels/ - the two
# trees the validator actually reads - so ordinary code commits are not taxed
# with a Godot boot.
#
# Two failure conditions:
#   1. any validator ERROR (the count has been zero since 8/1 and must stay)
#   2. the warning count rose against the committed docs/audits/validation_report.md
#
# Set BP_SKIP_VALIDATE=1 to bypass deliberately (e.g. committing a known-red
# work in progress). There is no accidental bypass.

set -e

if [ "$BP_SKIP_VALIDATE" = "1" ]; then
    echo "pre-commit: BP_SKIP_VALIDATE=1, skipping the content gate"
    exit 0
fi

staged=$(git diff --cached --name-only --diff-filter=ACMR)
case "$staged" in
    *data/*|*scripts/levels/*) ;;
    *)
        exit 0
        ;;
esac

repo=$(git rev-parse --show-toplevel)
godot="${BP_GODOT:-$USERPROFILE/_tools/godot47/Godot_v4.7-stable_win64_console.exe}"

if [ ! -f "$godot" ]; then
    echo "pre-commit: Godot 4.7 not found at $godot - set BP_GODOT to the binary" >&2
    exit 1
fi

echo "pre-commit: staged changes touch data/ or scripts/levels/, running the content validator"

output=$("$godot" --headless --path "$repo" --script res://tools/validate_content.gd 2>&1 || true)
verdict=$(printf '%s\n' "$output" | grep -E '^Errors: ' | tail -n 1)

if [ -z "$verdict" ]; then
    echo "pre-commit: the validator produced no verdict line - refusing to commit blind" >&2
    printf '%s\n' "$output" | tail -n 20 >&2
    exit 1
fi

errors=$(printf '%s' "$verdict" | sed -E 's/^Errors: ([0-9]+).*/\1/')
warnings=$(printf '%s' "$verdict" | sed -E 's/.*Warnings: ([0-9]+).*/\1/')

if [ "$errors" -ne 0 ]; then
    echo "pre-commit: $errors validator ERRORS. Errors must stay at zero." >&2
    echo "            See docs/audits/validation_report.md" >&2
    exit 1
fi

# The committed report is the ratchet. A change may lower the warning count or
# hold it; it may not raise it. Anything genuinely unfixable belongs in
# docs/audits/wave_b_dispositions.md with the question that blocks it.
baseline=$(git show HEAD:docs/audits/validation_report.md 2>/dev/null \
    | grep -E '^\| Warnings \| [0-9]+ \|' \
    | sed -E 's/^\| Warnings \| ([0-9]+) \|.*/\1/' | tail -n 1)

if [ -n "$baseline" ] && [ "$warnings" -gt "$baseline" ]; then
    echo "pre-commit: warnings rose $baseline -> $warnings." >&2
    echo "            Fix them, or record the reason in docs/audits/wave_b_dispositions.md" >&2
    echo "            and re-run. BP_SKIP_VALIDATE=1 bypasses deliberately." >&2
    exit 1
fi

echo "pre-commit: 0 errors, $warnings warnings (baseline ${baseline:-none}). OK."
exit 0
