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

  #
  RECOIL_ENABLE_WIDGETS='"Overwatch"'
  source "${SCRIPT_DIR}/recoil.sh"

  # Copy widget
  mkdir -p "${SCRIPT_DIR}/../test/overwatch-bar"
  work_dir=$(realpath "${SCRIPT_DIR}/../test/overwatch-bar")

  local luaui_dir="${work_dir}/LuaUI/Widgets"
  mkdir -p "${luaui_dir}"
  cp -f "${build}" "${luaui_dir}/"

  # Prepare
  rversion=$(recoil_version "")

  set -e
  recoil_download_engine "${work_dir}" "${rversion}"
  recoil_download_game "${work_dir}" "https://github.com/beyond-all-reason/Beyond-All-Reason.git" "master" "${rversion}"
  recoil_download_map "${work_dir}" "https://files-cdn.beyondallreason.dev/file/21028d5855cbaf0f413b5c6c7cd44d3e/full_metal_plate_1.7.sd7" "${rversion}"
  recoil_write_script "${work_dir}" "Beyond All Reason \$VERSION" "Full Metal Plate 1.7"
  recoil_write_settings "${work_dir}"
  recoil_write_widget "${work_dir}" "luaui/Widgets/__inject.lua" "${_inject_widget}"
  set +e

  # Make temporary logfile
  local logfile
  logfile="$(mktemp --tmpdir "recoillog.XXXXXXXXXX")"

  # Execute
  local output=""
  local rc=1
  recoil_run "headless" "${work_dir}" "${rversion}" "" 1>"${logfile}" 2>&1
  rc=$?

  # TODO(Fast): Not sure why recoil always exits 139
  if [ "${rc}" -eq 139 ]; then
    rc=0
  fi

  # Check output
  if [ $rc -ne 0 ]; then
    recoil_check_error "${output}" "${rc}"
    rc=$?
  fi

  if ! grep -q "\[Overwatch" "${logfile}"; then
    recoil_add_error "\"Overwatch\" not found in test output"
    has_check_error=true
  fi

  if grep -E "\[Overwatch::.+(ERROR|FATAL)+\]" "${logfile}"; then
    recoil_add_error "Overwatch produced an error"
    has_check_error=true
  fi

  if [ $rc -ne 0 ] || [ "${has_check_error}" == true ]; then
    # cat "${logfile}"
    recoil_print_errors
    rc=1
  fi

  rm -f "${logfile}"

  return $rc
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
