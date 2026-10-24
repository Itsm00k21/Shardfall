#!/bin/sh
# Installs git hooks that rerun scripts/stamp.sh after every commit,
# merge, checkout, and rebase, so the served BuildStamp is never stale.
set -e
hooks=$(git rev-parse --git-common-dir)/hooks
mkdir -p "$hooks"
for name in post-commit post-merge post-checkout post-rewrite; do
	file="$hooks/$name"
	if [ -f "$file" ] && ! grep -q "scripts/stamp.sh" "$file"; then
		echo "skip $name: a different hook is already there"
		continue
	fi
	cat > "$file" <<'HOOK'
#!/bin/sh
# Shardfall build stamp (scripts/install-hooks.sh)
if [ -f scripts/stamp.sh ]; then sh scripts/stamp.sh >/dev/null 2>&1 || true; fi
HOOK
	chmod +x "$file"
	echo "installed $name"
done
sh scripts/stamp.sh
