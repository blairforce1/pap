#!/bin/sh
# guard-route.test.sh: regression tests for the decision 0002 hook layer
# (plugins/pap/hooks/guard-route.sh routing to scripts/guard-branch.sh).
#
# Usage: sh tests/guard-route.test.sh
#
# Builds throwaway repositories in a temporary directory, feeds the router
# synthetic PreToolUse input, and checks its exit code: 2 blocks the call,
# 0 lets it through. Prints one TAP-style line per case and exits 1 if any
# case fails. Needs git and jq; touches nothing outside the temporary
# directory.
#
#   G     adopts decision 0002, on main
#   G2    adopts decision 0002, on change/x
#   G sp  adopts decision 0002, on main, path contains a space
#   D     adopts decision 0002, detached HEAD
#   U     does not adopt decision 0002, on main

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
router="$here/plugins/pap/hooks/guard-route.sh"
guard="$here/scripts/guard-branch.sh"

for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM

mkrepo() {
  git init -q -b main "$1"
  git -C "$1" -c user.name=test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q --allow-empty -m init
}
adopt() {
  mkdir -p "$1/scripts"
  cp "$guard" "$1/scripts/guard-branch.sh"
}

mkrepo "$T/G"    && adopt "$T/G"
mkrepo "$T/G2"   && adopt "$T/G2" && git -C "$T/G2" switch -q -c change/x
mkrepo "$T/G sp" && adopt "$T/G sp"
mkrepo "$T/D"    && adopt "$T/D"  && git -C "$T/D" switch -q --detach
mkrepo "$T/U"

n=0
failed=0

# check <expected exit> <cwd> <command> [tool name]
check() {
  n=$((n + 1))
  input="$(jq -nc --arg c "$3" --arg d "$2" --arg t "${4:-Bash}" \
    '{tool_name: $t, cwd: $d, tool_input: {command: $c}}')"
  printf '%s' "$input" | "$router" >/dev/null 2>&1
  rc=$?
  label="cwd=${2#"$T"/} ${4:+[$4] }$(printf '%s' "$3" | tr '\n' '~')"
  if [ "$rc" = "$1" ]; then
    printf 'ok %d - %s\n' "$n" "$label"
  else
    printf 'not ok %d - %s (exit %s, expected %s)\n' "$n" "$label" "$rc" "$1"
    failed=$((failed + 1))
  fi
}

# The session's own repository.
check 2 "$T/G"  'git commit -m x'
check 0 "$T/G2" 'git commit -m x'
check 2 "$T/D"  'git commit -m x'
check 0 "$T/U"  'git commit -m x'

# A session in a guarded repository must not block others (the dotfiles case).
check 0 "$T/G"  "cd $T/U && git commit -m x"
check 0 "$T/G"  "git -C $T/U commit -m x"

# A session elsewhere must not reach a guarded main.
check 2 "$T/U"  "cd $T/G && git commit -m x"
check 2 "$T/U"  "git -C $T/G commit -m x"
check 2 "$T/G2" "git -C $T/G push origin main"
check 2 "$T/U"  "git -c user.name=x -C $T/G commit"
check 2 "$T/G2" "cd ../G && GIT_AUTHOR_NAME=x git commit -m y"
check 2 "$T/U"  "cd \"$T/G sp\" && git commit -m x"

# Separators, subshells and sequences.
check 2 "$T/G"  "cd $T/U; git commit -m a && cd $T/G && git push"
check 2 "$T/U"  "(cd $T/G && git commit -m x)"
check 2 "$T/U"  "echo start | cat && cd $T/G && git commit -m x"
check 0 "$T/U"  "cd $T/G && git status && cd $T/U && git commit -m x"
check 0 "$T/G2" "cd ../G2 && git commit -m x"

# Not a commit or push, or not a Bash call.
check 0 "$T/U"  'git status'
check 0 "$T/G"  'git log --oneline | grep commit'
check 0 "$T/U"  "git -C $T/G log"
check 0 "$T/G"  'git commit -m x' Edit

# Targets that are not repositories.
check 0 "$T/U"  'cd ~/does-not-exist && git commit -m x'

# Decision 0005: hook bypasses are refused in an adopting repository. G2 is
# on change/x, so the branch check passes and only the bypass can refuse.
# Each pattern: direct, after cd, through git -C, after env, and in && and ;
# sequences.
for bypass in 'LEFTHOOK=0 git commit -m x' 'LEFTHOOK_EXCLUDE=lint git commit -m x' \
              'git commit --no-verify -m x' 'git commit -n -m x' 'git commit -anm x' \
              'git push --no-verify' 'git config core.hooksPath /dev/null'; do
  check 2 "$T/G2" "$bypass"
  check 2 "$T/U"  "cd $T/G2 && $bypass"
  check 2 "$T/G2" "env $bypass"
  check 2 "$T/U"  "cd $T/G2 && true && $bypass"
  check 2 "$T/U"  "cd $T/G2; $bypass"
done
check 2 "$T/U"  "git -C $T/G2 commit --no-verify -m x"
check 2 "$T/U"  "git -C $T/G2 commit -n -m x"
check 2 "$T/U"  "git -C $T/G2 push --no-verify"
check 2 "$T/U"  "git -C $T/G2 config core.hooksPath /dev/null"
check 2 "$T/U"  "LEFTHOOK=0 git -C $T/G2 commit -m x"
check 2 "$T/U"  "LEFTHOOK_EXCLUDE=lint git -C $T/G2 commit -m x"
check 2 "$T/U"  "env LEFTHOOK=0 git -C $T/G2 commit -m x"
check 2 "$T/U"  "env LEFTHOOK_EXCLUDE=lint git -C $T/G2 commit -m x"
check 2 "$T/G2" 'export LEFTHOOK=0 && git commit -m x'
check 2 "$T/G2" 'LEFTHOOK=0; git commit -m x'
check 2 "$T/G2" 'export LEFTHOOK=0'
check 2 "$T/G2" 'git commit --no-veri -m x'
check 2 "$T/G2" 'git -c core.hooksPath=/dev/null commit -m x'
check 2 "$T/G2" 'git --config-env=core.hooksPath=H commit -m x'
check 2 "$T/G2" 'git config --local core.HooksPath .no-hooks'

# Near misses that must pass.
check 0 "$T/G2" 'git commit -m "skip --no-verify next time"'
check 0 "$T/G2" "git commit -m 'why LEFTHOOK=0 is refused'"
check 0 "$T/G2" 'LEFTHOOK_VERBOSE=1 git commit -m x'
check 0 "$T/G2" 'git push -n origin change/x'
check 0 "$T/G2" 'git commit -m n'
check 0 "$T/G2" 'git commit -uno -m x'
check 0 "$T/G2" 'git commit -m "fix core.hooksPath docs"'
check 0 "$T/G2" 'git log --grep=--no-verify'

# A bypass in a repository that does not adopt PAP is not this hook's business.
check 0 "$T/U"  'git commit --no-verify -m x'
check 0 "$T/G2" "LEFTHOOK=0 git -C $T/U commit -m x"
check 0 "$T/G2" "cd $T/U && git config core.hooksPath /dev/null"

# Decision 0012: an agent may not write an Approved-by line into a pull
# request body, by any route, even to keep one the live body already has.
printf 'Summary\n- [ ] No protected path touched\n  Approved-by: @owner\n' > "$T/G2/approved.md"
printf 'Summary\nApproved by the owner later.\n' > "$T/G2/plain.md"
printf '{"body":"x\\napproved-BY: @owner"}' > "$T/G2/approved.json"
printf '{"body":"x\\nno approval"}' > "$T/G2/plain.json"
nl='
'
check 2 "$T/G2" "gh pr create --draft --title t --body \"x${nl}Approved-by: @owner\""
check 0 "$T/G2" "gh pr create --draft --title t --body \"x${nl}no approval\""
check 2 "$T/G2" "gh pr edit 7 -b 'x${nl}  approved-BY: @owner'"
check 0 "$T/G2" "gh pr edit 7 -b 'x'"
check 2 "$T/G2" "gh pr edit 7 --body=\$'x\\nApproved-by: @owner'"
check 2 "$T/G2" 'gh pr create --body-file approved.md'
check 0 "$T/G2" 'gh pr create --body-file plain.md'
check 2 "$T/U"  "cd $T/G2 && gh pr edit 7 -F approved.md"
check 2 "$T/G2" "gh pr edit 7 -F $T/G2/approved.md"
check 0 "$T/G2" 'gh pr edit 7 -F missing.md'
check 2 "$T/G2" "gh pr edit 7 --body-file - <<'EOF'${nl}Summary${nl}Approved-by: @owner${nl}EOF"
check 0 "$T/G2" "gh pr edit 7 --body-file - <<'EOF'${nl}Summary${nl}EOF"
check 2 "$T/G2" "cat <<EOF | gh pr create -F -${nl}Approved-By:@owner${nl}EOF"
check 2 "$T/G2" "gh pr create --body \"\$(cat <<'EOF'${nl}Approved-by: @owner${nl}EOF${nl})\""
check 0 "$T/G2" "gh pr create --body \"\$(cat <<'EOF'${nl}Summary${nl}EOF${nl})\""
check 2 "$T/G2" "gh api repos/o/r/pulls/7 -X PATCH -f body=\"x${nl}Approved-by: @owner\""
check 0 "$T/G2" "gh api repos/o/r/pulls/7 -X PATCH -f body=\"x${nl}no approval\""
check 2 "$T/G2" 'gh api repos/o/r/pulls/7 -X PATCH -F body=@approved.md'
check 0 "$T/G2" 'gh api repos/o/r/pulls/7 -X PATCH -F body=@plain.md'
check 2 "$T/G2" 'gh api -X PATCH repos/o/r/pulls/7 --input approved.json'
check 0 "$T/G2" 'gh api -X PATCH repos/o/r/pulls/7 --input plain.json'
check 2 "$T/G2" "gh api -X PATCH repos/o/r/pulls/7 --input - <<'EOF'${nl}{\"body\":\"x\\nApproved-by: @owner\"}${nl}EOF"
check 2 "$T/G2" "gh api repos/o/r/pulls -f title=t -f head=change/x -f base=main -f body=\"Approved-by: @owner\""

# Approved-by elsewhere, not in a pull request body, passes.
check 0 "$T/G2" "git commit -m \"x${nl}${nl}Approved-by: @owner\""
check 0 "$T/G2" "git commit -F - <<'EOF'${nl}x${nl}Approved-by: @owner${nl}EOF"
check 0 "$T/G2" "gh pr comment 7 --body \"Approved-by: @owner\""
check 0 "$T/G2" "gh pr view 7 --json body | grep -i 'Approved-by:'"
check 0 "$T/G2" "gh pr create --title 'Approved-by: @owner' --body x"
check 0 "$T/G2" "gh pr edit 7 --body \"see the Approved-by: line\""
check 0 "$T/G2" "gh api repos/o/r/issues/7/comments -f body=\"Approved-by: @owner\""
check 0 "$T/U"  "gh pr edit 7 --body \"Approved-by: @owner\""
# Decision 0013: the box's "Head to approve:" reason is the agent's, and
# passes; the Approved-by line it asks for stays the owner's.
printf 'Summary\n- [ ] No protected path touched, or an owner has approved the head: Approved-by: @login <sha> below\n  Head to approve: 3f9c2a7\n' > "$T/G2/head.md"
check 0 "$T/G2" 'gh pr edit 7 --body-file head.md'
check 0 "$T/G2" "gh pr create --draft --title t --body \"x${nl}  Head to approve: 3f9c2a7\""
check 2 "$T/G2" "gh pr edit 7 --body \"x${nl}  Head to approve: 3f9c2a7${nl}  Approved-by: @owner 3f9c2a7\""

# Without jq the router cannot parse; it complains only where the session's
# own repository is guarded, and never blocks.
mkdir -p "$T/bin"
for b in git cat; do ln -s "$(command -v "$b")" "$T/bin/$b"; done
for repo in G U; do
  n=$((n + 1))
  printf '{}' | env -i HOME="$HOME" PATH="$T/bin" CLAUDE_PROJECT_DIR="$T/$repo" \
    /bin/sh "$router" >/dev/null 2>&1
  rc=$?
  want=0
  [ "$repo" = G ] && want=1
  if [ "$rc" = "$want" ]; then
    printf 'ok %d - no jq, session in %s\n' "$n" "$repo"
  else
    printf 'not ok %d - no jq, session in %s (exit %s, expected %s)\n' "$n" "$repo" "$rc" "$want"
    failed=$((failed + 1))
  fi
done

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }
