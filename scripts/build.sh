#!/usr/bin/env bash

# Build script configuration
SRC_DIR="lua"
OUTPUT_DIR="dist"
DEBUG_OUTPUT="${OUTPUT_DIR}/debug/overwatch.lua"
RELEASE_OUTPUT="${OUTPUT_DIR}/overwatch.lua"

function build_lua_rml() {
  echo "Creating -rml.lua and -rcss.lua files..."
  for f in $(find ${SRC_DIR}/ -name '*rml'); do
    local nf="${f%.rml}-rml.lua"
    echo -e "-- AUTO Generated: DO NOT EDIT\nreturn [[" > $nf
    cat $f >> $nf
    echo "" >> $nf
    echo "]]" >> $nf
  done

  for f in $(find ${SRC_DIR}/ -name '*rcss'); do
    local nf="${f%.rcss}-rcss.lua"
    echo -e "-- AUTO Generated: DO NOT EDIT\nreturn [[" > $nf
    cat $f >> $nf
    echo "" >> $nf
    echo "]]" >> $nf
  done

  echo "Done"
}

# Build functions
function build_debug() {
  build_lua_rml

  echo "Building debug version..."
  luapack bundle lua/main.lua --output="${DEBUG_OUTPUT}"
  echo "Debug build complete: ${DEBUG_OUTPUT}"
}

function build_release() {
  build_lua_rml

  echo "Building release version..."
  # Temporarily change to release mode
  sed -i 's/^local IS_RELEASE = false$/local IS_RELEASE = true/' "${SRC_DIR}/core/constants.lua"

  # Build release version
  luapack bundle lua/main.lua --output="${RELEASE_OUTPUT}"

  # Revert back to debug mode
  sed -i 's/^local IS_RELEASE = true$/local IS_RELEASE = false/' "${SRC_DIR}/core/constants.lua"

  echo "Release build complete: ${RELEASE_OUTPUT}"
}

function watch_mode_debug() {
  echo "Starting watch mode. Press Ctrl+C to exit."

  # Build once initially
  build_debug

  # Then watch for changes
  echo "Watching for changes in ${SRC_DIR}..."
  while inotifywait -e close_write -r "${SRC_DIR}"; do
    echo "Changes detected, rebuilding..."
    build_debug || continue
  done
}

function watch_mode_release() {
  echo "Starting watch mode. Press Ctrl+C to exit."

  # Build once initially
  build_release

  # Then watch for changes
  echo "Watching for changes in ${SRC_DIR}..."
  while inotifywait -e close_write -r "${SRC_DIR}"; do
    echo "Changes detected, rebuilding..."
    build_release || continue
  done
}

# Git commit functions
function show_status() {
  echo "Current Git Status:"
  git status -s
  echo ""
}

function commit_changes() {
  local message="$1"

  if [ -z "$message" ]; then
    echo "Error: Commit message is required"
    return 1
  fi

  # Add all changes
  git add -A

  # Commit with the provided message
  git commit -m "$message"

  if [ $? -eq 0 ]; then
    echo "Successfully committed changes with message: $message"
    return 0
  else
    echo "Failed to commit changes"
    return 1
  fi
}

function commit_workflow() {
  # Show current status
  show_status

  # Ask if user wants to commit
  read -p "Do you want to commit the current changes? (y/n): " commit_choice

  if [[ $commit_choice =~ ^[Yy]$ ]]; then
    # Ask for commit message
    read -p "Enter commit message: " commit_message

    # Commit changes
    commit_changes "$commit_message"

    if [ $? -eq 0 ]; then
      echo "Ready to apply new changes!"
    else
      echo "Commit failed. Please resolve issues before proceeding."
      exit 1
    fi
  else
    echo "Skipping commit. Proceeding without committing current changes."
  fi
}

# Parse command line arguments
COMMAND="all"
if [ $# -gt 0 ]; then
  COMMAND=$1
fi

# Execute requested command
case "${COMMAND}" in
  "debug")
    build_debug
    ;;
  "release")
    build_release
    ;;
  "watch")
    watch_mode_debug
    ;;
  "watch-release")
    watch_mode_release
    ;;
  "commit")
    commit_workflow
    ;;
  "build-commit")
    build_debug
    build_release
    commit_workflow
    ;;
  "build" | *)
    build_debug
    build_release
    ;;
esac