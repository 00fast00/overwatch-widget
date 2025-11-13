#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Build script configuration
SRC_DIR="lua"
OUTPUT_DIR="dist"
DEBUG_OUTPUT="${OUTPUT_DIR}/debug/overwatch.lua"
RELEASE_OUTPUT="${OUTPUT_DIR}/overwatch.lua"
BAR_REPO=$(realpath "${SCRIPT_DIR}/../../Beyond-All-Reason")

build_lua_rml() {
  echo "Creating -rml.lua and -rcss.lua files..."
  while IFS= read -r -d '' file; do
    printf -- "-- AUTO Generated: DO NOT EDIT\nreturn [[%s\n]]\n" "$(cat "${file}")" >"${file%.rml}-rml.lua"
  done < <(find "${SRC_DIR}" -name '*.rml' -print0)

  while IFS= read -r -d '' file; do
    printf -- "-- AUTO Generated: DO NOT EDIT\nreturn [[%s\n]]\n" "$(cat "${file}")" >"${file%.rcss}-rcss.lua"
  done < <(find "${SRC_DIR}" -name '*.rcss' -print0)
  echo "Done"
}

build() {
  local flavor=$1

  build_lua_rml

  if [ "${flavor}" == "release" ]; then
    echo "Building release version..."
    # Temporarily change to release mode
    sed -i 's/^local IS_RELEASE = false$/local IS_RELEASE = true/' "${SRC_DIR}/core/constants.lua"

    # Build release version
    luapack bundle lua/main.lua --output="${RELEASE_OUTPUT}" 2>&1

    # Revert back to debug mode
    sed -i 's/^local IS_RELEASE = true$/local IS_RELEASE = false/' "${SRC_DIR}/core/constants.lua"

    echo "Release build complete: ${RELEASE_OUTPUT}"
  else
    echo "Building debug version..."
    luapack bundle lua/main.lua --output="${DEBUG_OUTPUT}" 2>&1
    echo "Debug build complete: ${DEBUG_OUTPUT}"
  fi
}

watch() {
  local flavor=$1

  echo "Starting watch mode. Press Ctrl+C to exit."

  # Build once initially
  build "${flavor}"

  # Then watch for changes
  echo "Watching for changes in ${SRC_DIR}..."
  while inotifywait -e close_write -r "${SRC_DIR}"; do
    echo "Changes detected, rebuilding..."
    build "${flavor}" || continue
  done
}

test() {
  local flavor=$1

  local build=""
  if [ "${flavor}" == "release" ]; then
    build="${RELEASE_OUTPUT}"
  else
    build="${DEBUG_OUTPUT}"
  fi

  source "${SCRIPT_DIR}/recoil.sh"

  # shellcheck disable=SC2034
  ENABLE_WIDGETS='"Overwatch"'

  local work_dir
  mkdir -p "${SCRIPT_DIR}/../test/overwatch-bar"
  work_dir=$(realpath "${SCRIPT_DIR}/../test/overwatch-bar")

  local luaui_dir="${work_dir}/LuaUI/Widgets"
  mkdir -p "${luaui_dir}"
  cp -f "${build}" "${luaui_dir}/"

  # Run spring-headless
  local output
  # recoil_enable_log
  output=$(recoil_run "headless" "${work_dir}" "${BAR_REPO}" "master" "" "${RECOIL_DEFAULT_MAP_URL}" "${RECOIL_DEFAULT_GAME}" "${RECOIL_DEFAULT_MAP}" "" true | tee -a -i /dev/tty)
  local rc=$?

  # Check for widget stuff
  local has_check_error=false
  if ! printf "%s" "${output}" | grep "Overwatch" 1>/dev/null; then
    recoil_log_error_buff "\"Overwatch\" not found in test output"
    has_check_error=true
  fi

  if [ "${has_check_error}" == true ]; then
    recoil_print_error_buff
    rc=1
  fi

  return ${rc}
}

# Git commit functions
show_status() {
  echo "Current Git Status:"
  git status -s
  echo ""
}

commit_changes() {
  local message="$1"

  if [ -z "$message" ]; then
    echo "Error: Commit message is required"
    return 1
  fi

  # Add all changes
  git add -A

  # Commit with the provided message
  if git commit -m "$message"; then
    echo "Successfully committed changes with message: $message"
    return 0
  else
    echo "Failed to commit changes"
    return 1
  fi
}

commit() {
  # Show current status
  show_status

  # Ask if user wants to commit
  read -r -p "Do you want to commit the current changes? (y/n): " commit_choice

  if [[ $commit_choice =~ ^[Yy]$ ]]; then
    # Ask for commit message
    read -r -p "Enter commit message: " commit_message

    # Commit changes
    if commit_changes "$commit_message"; then
      echo "Ready to apply new changes!"
    else
      echo "Commit failed. Please resolve issues before proceeding."
      exit 1
    fi
  else
    echo "Skipping commit. Proceeding without committing current changes."
  fi
}

main() {
  # Execute requested command
  case "${1:-"build-test"}" in
  "debug")
    build "debug"
    ;;
  "release")
    build "release"
    ;;
  "watch")
    watch "debug"
    ;;
  "watch-release")
    watch "release"
    ;;
  "commit")
    commit
    ;;
  "build")
    build "debug"
    build "release"
    ;;
  "build-test")
    build "debug"
    if ! test "debug"; then
      exit 1
    fi

    build "release"
    if ! test "relase"; then
      exit 1
    fi
    ;;
  "build-test-commit")
    build "debug"
    if ! test "debug"; then
      exit 1
    fi

    build "release"
    if ! test "relase"; then
      exit 1
    fi

    commit
    ;;
  esac
}

main "${@}"
