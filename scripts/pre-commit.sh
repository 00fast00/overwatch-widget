#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

echo "[pre-commit] stylua --check lua/**"
stylua --check lua/**

echo "[pre-commit"] shellcheck
# shellcheck disable=SC2086
shellcheck ${SCRIPT_DIR}/*.sh

echo "[pre-commit] ${SCRIPT_DIR}/build.sh build-test"
"${SCRIPT_DIR}/build.sh" build-test