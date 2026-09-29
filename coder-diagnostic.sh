#!/usr/bin/env bash
# Read-only diagnostic for the coder workspace pod. Writes nothing. Masks tokens.
PERSIST="${PERSIST:-$HOME/ebs}"
{
echo "== os =="; uname -srm; grep -E '^(PRETTY_NAME|ID)=' /etc/os-release
echo; echo "== claude =="; command -v claude; claude --version 2>&1 | head -1
echo "CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR:-<unset>}"
echo; echo "== home & persistence =="; echo "HOME=$HOME"; ls -la "$HOME" | head -40
echo "-- ~/.claude:"; readlink -f ~/.claude 2>/dev/null || echo "(absent)"; ls ~/.claude 2>/dev/null
echo "-- ~/.claude.json:"; ls -la ~/.claude.json 2>/dev/null || echo "(absent)"
echo "-- $PERSIST:"; ls -la "$PERSIST" 2>/dev/null | head -40; df -h "$PERSIST" 2>/dev/null | tail -1
echo "-- mounts:"; mount | grep -E "$(basename "$PERSIST")|home"
echo; echo "== managed / project settings =="
for f in /etc/claude-code/managed-settings.json ~/.claude/settings.json ~/.claude/settings.local.json ~/.claude/CLAUDE.md; do
  echo "-- $f"; [ -f "$f" ] && sed -E 's/(key|token|secret|password)[^,}]*/\1: <masked>/Ig' "$f" || echo "(absent)"
done
echo; echo "== env (masked) =="
env | grep -iE '^(ANTHROPIC|CLAUDE|LITELLM|OPENAI|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|http_proxy|https_proxy|no_proxy|NPM_|PIP_|UV_|MAVEN|JAVA_HOME|GIT_)' \
  | sed -E 's/^([^=]*(KEY|TOKEN|SECRET|PASSWORD)[^=]*)=.*/\1=<masked>/I'
echo; echo "== toolchain =="
for t in git jq curl node npm pnpm yarn bun python3 uv pip pip3 rg fd ast-grep shellcheck shfmt prek pre-commit rtk java mvn gradle scala sbt go cargo docker podman kubectl gh agentctl; do
  printf '%-12s %s\n' "$t" "$(command -v $t 2>/dev/null || echo -)"
done
node --version 2>/dev/null; python3 --version 2>/dev/null; java -version 2>&1 | head -1
echo; echo "== registries =="
npm config get registry 2>/dev/null; pip config list 2>/dev/null; [ -f ~/.npmrc ] && sed -E 's/(_authToken|_auth|password)=.*/\1=<masked>/' ~/.npmrc
git config --global -l 2>/dev/null | grep -iE 'url|proxy|credential' | sed -E 's/(token|password)=.*/\1=<masked>/I'
echo; echo "== reachability (HTTP code or fail) =="
for u in https://github.com https://api.github.com https://registry.npmjs.org https://pypi.org https://bitbucket.org https://api.anthropic.com; do
  printf '%-32s %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$u" 2>/dev/null || echo fail)"
done
echo; echo "== claude mcp / plugins =="
claude mcp list 2>&1 | head -30
claude plugin list 2>&1 | head -30
echo; echo "== projects =="
for d in "$PERSIST"/*/ ~/*/; do
  [ -d "$d/.git" ] || continue
  echo "-- $d: $(git -C "$d" remote get-url origin 2>/dev/null | sed -E 's#//[^@]*@#//<user>@#')"
  for m in pom.xml build.gradle build.gradle.kts package.json pnpm-lock.yaml pyproject.toml requirements.txt go.mod Cargo.toml build.sbt CLAUDE.md AGENTS.md .pre-commit-config.yaml .claude .mcp.json Makefile; do
    [ -e "$d/$m" ] && printf '%s ' "$m"
  done; echo
done
} 2>&1
