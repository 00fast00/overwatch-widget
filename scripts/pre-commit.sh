#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
WORKSPACE_DIR=$(realpath "${SCRIPT_DIR}/..")

echo "[pre-commit] stylua --check ${WORKSPACE_DIR}/lua/**"
stylua --check "${WORKSPACE_DIR}/lua/**" 1>/dev/null

echo "[pre-commit] shellcheck ${SCRIPT_DIR}/*.sh"
# shellcheck disable=SC2086
shellcheck ${SCRIPT_DIR}/*.sh 1>/dev/null

echo "[pre-commit] markdownlint-cli2 ${WORKSPACE_DIR}/**.md"
markdownlint-cli2 "${WORKSPACE_DIR}/**.md"

echo "[pre-commit] ${SCRIPT_DIR}/build.sh build-test"
"${SCRIPT_DIR}/build.sh" build-test 1>/dev/null
