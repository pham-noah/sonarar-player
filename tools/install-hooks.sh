#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath tools/hooks
printf 'hooks installed: %s\n' "$(git config core.hooksPath)"
ls -1 tools/hooks
