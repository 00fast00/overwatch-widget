#!/usr/bin/env bash
set -euo pipefail

echo "[pre-commit] stylua --check lua/**"
stylua --check lua/**