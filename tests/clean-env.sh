# clean-env.sh: sourced by every suite before it runs git or gh, so a suite
# sees the same environment in an agent shell (pap claude) as in CI. pap
# claude exports GH_CONFIG_DIR, CLAUDECODE, a GIT_CONFIG_COUNT credential
# helper and the session's mode, PAP_MODE; a suite that inherits them tests
# the session, not the code.
# shellcheck shell=sh
for v in $(env | sed -n 's/^\(GIT_CONFIG_KEY_[0-9]*\)=.*/\1/p; s/^\(GIT_CONFIG_VALUE_[0-9]*\)=.*/\1/p'); do
  unset "$v"
done
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL \
  GH_CONFIG_DIR GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN \
  CLAUDECODE CLAUDE_CODE_ENTRYPOINT PAP_SHELL_INIT PAP_MODE PAP_PM_NOW
export GIT_CONFIG_NOSYSTEM=1
