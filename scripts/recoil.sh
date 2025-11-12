#!/usr/bin/env bash
set -euo pipefail

# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <https://unlicense.org/>
#
# This is highly customizable and modular. Think it's easy to understand and adopt.
#
# Note: To test you'r own work you might wanna copy it into "LuaUI/Widgets/" before running this.
# 
#
_cmd="$0"
_usage=$(cat <<EOF
$_cmd is a helper to setup a test environment for mods/widgets and test them with spring/spring-headless.

Usage: $_cmd <full-silent|full|headless-silent|headless|run> <DIRECTORY-TO-RUN-IN> [git-repo] [git-branch] [map-url] [recoil-version] [recoil-options...]

    full*: Runs with spring
    headless*: Runs with spring-headless
    run: Runs spring without a injected "quit" widget for local test runs

It does:

    - downloads (if not there):
        - recoil (latest version auto-detected if wanted)
        - game/mod (using git)
        - A map
    - customizes the game with a widget to enable any other widget and quit the game after x seconds
    - writes a custom RECOIL_DEFAULT_SETTINGS.cfg
    - run's spring or spring-headless
    - checks the output for common errors (grep + pcregrep)
    - removes the custom widget
    - print's the output

Examples:

    # Run headless in silent mode (only output on error with complete log)
    $ $_cmd headless-silent test


    # Run the game with script defaults
    $ $_cmd run test/bar

    # Run headless with a local git repo
    $ $_cmd headless test/bar-local ../Beyond-All-Reason

    # Run TeachA :)
    $ $_cmd run test/techa https://github.com/techannihilation/TA.git master http://www.hakora.xyz/files/springrts/maps/techno_lands_final_26.0.sd7 "" --game 'Tech Annihilation \$VERSION' --map 'Techno Lands Final 26.0'

As a library:

    DEBUG_OUTPUT="\${OUTPUT_DIR}/debug/overwatch.lua"
    RELEASE_OUTPUT="\${OUTPUT_DIR}/overwatch.lua"
    BAR_REPO=\$(realpath "\${SCRIPT_DIR}/../../Beyond-All-Reason")

    test() {
        local flavor=\$1

        local build=""
        if [ "\${flavor}" == "release" ]; then
        build="\${RELEASE_OUTPUT}"
        else
        build="\${DEBUG_OUTPUT}"
        fi

        source "\${SCRIPT_DIR}/recoil.sh"

        # shellcheck disable=SC2034
        ENABLE_WIDGETS='"Overwatch"'

        local work_dir
        mkdir -p "\${SCRIPT_DIR}/../test/local-bar"
        work_dir=\$(realpath "\${SCRIPT_DIR}/../test/local-bar")

        local luaui_dir="\${work_dir}/LuaUI/Widgets"
        mkdir -p "\${luaui_dir}"
        cp -f "\${build}" "\${luaui_dir}/"


        # Run spring-headless
        local output
        # recoil_enable_log
        output=\$(recoil_run "headless" "\${work_dir}" "\${BAR_REPO}" "master" "" "\${RECOIL_DEFAULT_MAP_URL}" "\${RECOIL_DEFAULT_SETTINGS}" "\${RECOIL_DEFAULT_ARGS}" true)
        local rc=\$?

        # Check for widget stuff
        local has_check_error=false
        if ! printf "%s" "\${output}" | grep "Overwatch" 1>/dev/null; then
        printf "ERROR: \"Overwatch\" not found in test output\n" > /dev/stderr
        has_check_error=true
        fi

        if [ "\${has_check_error}" == true ]; then
        printf "%s\n" "\${output}"
        rc=1
        fi

        return \${rc}
    }

    test()

EOF
)

#
##### Config
#
RECOIL_DEFAULT_GAME_REPO=${RECOIL_DEFAULT_GAME_REPO:-"https://github.com/beyond-all-reason/Beyond-All-Reason.git"}
RECOIL_DEFAULT_GAME_BRANCH=${RECOIL_DEFAULT_GAME_BRANCH:-"master"}
RECOIL_DEFAULT_MAP_URL=${RECOIL_DEFAULT_MAP_URL:-"https://files-cdn.beyondallreason.dev/file/21028d5855cbaf0f413b5c6c7cd44d3e/full_metal_plate_1.7.sd7"}
RECOIL_DEFAULT_ARGS=${RECOIL_DEFAULT_ARGS:-"--game 'Beyond All Reason \$VERSION' --map 'Full Metal Plate 1.7'"}

# springsettings.cfg contents
RECOIL_DEFAULT_SETTINGS=${RECOIL_DEFAULT_SETTINGS:-"AllowDeferredMapRendering = 1
AllowDeferredModelRendering = 1
AllowDrawMapDeferredEvents = 1
BuildWarnings = 1
BumpWaterAnisotropy = 2
BumpWaterBlurReflection = 1
BumpWaterDepthBits = 32
BumpWaterReflection = 2
BumpWaterTexSizeReflection = 1024
CamMode = 3
CamSpringMinZoomDistance = 300
ChobbyLaunchesCount = 2
CrossAlpha = 0
CubeTexGenerateMipMaps = 1
CubeTexSizeReflection = 1024
CubeTexSpecularExponent = 100
DisplayDebugPrefixConsole = 0
DualScreenMiniMapOnLeft = 1
EdgeMoveDynamic = 0
EdgeMoveWidth = 0.003
FPSFOV = 90
FeatureDrawDistance = 600000
FeatureFadeDistance = 600000
FirstRun = 0
FogMult = 1
FontFile = FreeSansBold.otf
FontOutlineWeight = 2
FontOutlineWidth = 6
FontSize = 40
GrassDetail = 0
GroundDecals = 2
GroundDetail = 200
HangTimeout = 30
HardwareCursor = 1
InitialNetworkTimeout = 0
InputTextGeo = 0.35 0.72 0.03 0.04
KeyChainTimeout = 333
KeyboardLayout = qwerty
LinkBandwidth = 0
LinkIncomingMaxPacketRate = 2048
LinkIncomingPeakBandwidth = 1048576
LinkIncomingSustainedBandwidth = 1048576
LinkOutgoingBandwidth = 196608
LogFlush = 1
LogFlushLevel = 0
RotateLogFiles = 0
LuaAutoModWidgets = 1
LuaGarbageCollectionMemLoadMult = 1
LuaGarbageCollectionRunTimeMult = 1
MSAA = 1
MSAALevel = 4
MaxDynamicModelLights = 0
MaxParticles = 15000
MaxTextureAtlasSizeX = 8192
MaxTextureAtlasSizeY = 8192
MaxTextureAtlasSizeZ = 8192
MaximumTransmissionUnit = 0
MiddleClickScrollSpeed = -0.001
MiniMapMarker = 0
MinimapOnLeft = 1
MouseDragBoxCommandThreshold = 37
MouseDragCircleCommandThreshold = 37
MouseDragFrontCommandThreshold = 37
MouseDragScrollThreshold = 0
MouseDragSelectionThreshold = 21
MoveWarnings = 0
NetworkLossFactor = 2
NormalMapping = 1
OverheadMaxHeightFactor = 1.39999998
OverheadMinZoomDistance = 300
OverheadScrollSpeed = 50
RapidTagResolutionOrder = repos-cdn.beyondallreason.dev;repos.beyondallreason.dev
ReconnectTimeout = 0
ReflectiveWater = 4
Roam = 1
RotateLogFiles = 1
ServerSleepTime = 1
ShadowMapSize = 2803
Shadows = 1
ShowFPS = 1
ShowFps = 0
ShowPlayerInfo = 0
ShowSpeed = 1
SmallFontFile = FreeSansBold.otf
SmallFontOutlineWeight = 2
SmallFontOutlineWidth = 6
SmallFontSize = 40
SmoothLines = 1
SmoothPoints = 1
SmoothTimeOffset = 2
SplashScreenDir = ./MenuLoadscreens
TreeRadius = 1200
UnitIconDist = 160
UnitIconFadeAmount = 0.1
UnitIconFadeVanish = 3000
UnitIconScaleUI = 1.05
UnitIconsAsUI = 1
UnitIconsHideWithUI = 1
UseDistToGroundForIcons = 1.10000002
UseHighResTimer = 1
UseLuaMemPools = 0
UseNetMessageSmoothingBuffer = 0
UseSoundtrackAprilFools = 1
UseSoundtrackHalloween = 1
UseSoundtrackXmas = 1
VFSCacheArchiveFiles = 0
VSyncGame = -1
VerboseLevel = 10
Version = 2
Water = 4
WelcomeMessagePlayed = 1
WindowPosY = 0
WorkerThreadSpinTime = 5
XResolution = 2560
YResolution = 1440
cursorsize = 1
envAmbient = 0.25
modelGamma = 1
music = 1
music_loadscreen_track = music/original/loading/leon devereux - surfacefall.ogg
skirmish_faction_choice = 3
skirmish_gameType_choice = 4
skirmish_map_choice = 4
snd_airAbsorption = 0.35
snd_general = 100
snd_volmaster = 80
snd_volmusic = 30
tonemapA = 4.75
tonemapB = 0.75
tonemapC = 3.5
tonemapD = 0.85
tonemapE = 1
ui_opacity = 0.6
ui_rendertotexture = 1
ui_scale = 0.94
unitExposureMult = 1
unitSunMult = 1
version = 8"}

# Spring.Quit() at x seconds
QUIT_AT=${QUIT_AT:-5}

# Lua { `here` } - widgets to enable via widgethandler:EnableWidget()
# Example: ENABLE_WIDGETS='"Widget1", "Widget2"'
ENABLE_WIDGETS=${ENABLE_WIDGETS:-''}

###
#
#### END OF CONFIG
#

###
# Globals
_log_silent=true
###

###
# Templates
_inject_widget=$(cat <<EOF
--
-- AUTO GENERATED: DO NOT COMMIT
--
local QUIT_AT = ${QUIT_AT}
local ENABLE_WIDGETS = { ${ENABLE_WIDGETS} }

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "__injected",
		desc = "Injected widget",
		author = "Fast",
		date = "2025",
		license = "The Unlicense or GPL 2.0",
		layer = -99990 + 1, -- after gui_options
		enabled = true,
		handler = true,
	}
end

function widget:Initialize()
	for _, w in ipairs(ENABLE_WIDGETS) do
		-- if widgetHandler:IsWidgetKnown(w) then
		widgetHandler:EnableWidget(w)
		-- end
	end
end

function widget:GameFrame()
	if Spring.GetGameSeconds() >= QUIT_AT then
		Spring.Echo("Test Quit -> Quit", QUIT_AT)
		Spring.Quit()
	end
end
EOF
)
###

#
# Helper
#

# https://stackoverflow.com/a/17841619
function __join { local IFS="$1"; shift; echo "$*"; }

__log() {
    if [ "${_log_silent}" == true ]; then
        return
    fi

    printf "SCRIPT: %s\n" "$*"
}

__log_error() {
    printf "ERROR: %s\n" "$*" >&2
}

__require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        __log_error "required command not found: $1"
        exit 2
    }
}

#
# Code
#
recoil_enable_log() {
    _log_silent=false
}

#
# Detect version if it's empty
#
recoil_version() {
    __require_cmd curl

    local version="$1"
    
    if [ -n "${version}" ]; then
        printf "%s" "${version}"
        return 0
    fi

    local repo="beyond-all-reason/RecoilEngine"

    version=$(curl --fail --show-error --silent "https://api.github.com/repos/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$version" ]; then
        __log_error "Failed to detect latest release for ${repo}"
        return 1
    fi

    printf "%s" "${version}"
    return 0
}


#
# Download game if needed.
#
recoil_download_game() {
    __require_cmd git

    local recoil_dir=$1
    local repo=$2
    local branch=$3

    local packages_dir="${recoil_dir}/packages"
    if [ ! -d "${packages_dir}" ]; then
        mkdir -p "${packages_dir}"
    fi

    if [ ! -d "${packages_dir}/game.sdd" ]; then
        __log "Downloading game: ${repo}"
        git clone --depth 1 -b "${branch}" "${repo}" "${packages_dir}/game.sdd"
    fi
}

#
# Download engine if needed.
#
recoil_download_engine() {
    __require_cmd curl
    __require_cmd 7z

    local work_dir="$1"
    local version="$2"

    local url="https://github.com/beyond-all-reason/RecoilEngine/releases/download/${version}/recoil_${version}_amd64-linux.7z"
    local engine_dir="${work_dir}/engine/recoil_${version}"
    if [ ! -d "${engine_dir}" ]; then
        mkdir -p "${engine_dir}"
    fi

    if [ ! -x "${engine_dir}/spring" ]; then
        pushd "${engine_dir}" 1>/dev/null
        
        __log "Downloading Recoil ${version}: ${url}"
        curl --fail --show-error --silent --location "${url}" -o recoil.7z
        
        7z x -r -y recoil.7z 1>/dev/null 2>&1
        rm -f recoil.7z

        popd 1>/dev/null
    fi

    __log "Using Recoil ${version}"
}

#
# Download map if needed.
#
recoil_download_map() {
    local work_dir="$1"
    local url="$2"

    local map_dir="${work_dir}/maps"
    local map_file=""
    map_file=$(basename "${url}")

    if [ ! -d "${map_dir}" ]; then
        mkdir -p "${map_dir}"
    fi

    if [ ! -f "${map_dir}/${map_file}" ]; then
        pushd "${map_dir}" 1>/dev/null

        __log "Downloading map: ${map_file}"
        curl --fail --show-error --silent --location "${url}" -o "${map_file}"

        popd 1>/dev/null
    fi
}

recoil_write_widget() {
    local widget_path="$1"
    local content="$2"

    __log "Writing widget: ${widget_path}"
    
    local tmp
    tmp=$(mktemp "${widget_path}.XXXXXX")
    printf '%s' "${content}" > "${tmp}"
    
    mv -f "${tmp}" "${widget_path}"
}

recoil_write_settings() {
    local work_dir="$1"
    local settings="$2"

    __log "Writing ${work_dir}/springsettings.cfg"
    
    local tmp
    tmp=$(mktemp "${work_dir}/springsettings.cfg.XXXXXX")
    printf '%s' "${settings}" > "${tmp}"
    
    mv -f "${tmp}" "${work_dir}/springsettings.cfg"
}

recoil_run_engine() {
    local mode="$1" # full|headless|direct
    local work_dir="$2"
    local version="$3"
    local args="$4"

    local output=""
    local rc=1

    local spring="${work_dir}/engine/recoil_${version}/spring-headless"

    if [ "${mode}" != "headless" ]; then
        spring="${work_dir}/engine/recoil_${version}/spring"
    fi

    local old_IFS=$IFS
    local -a ea
    IFS=" " read -r -a ea <<< "${args}"
    IFS=$old_IFS

    local -a cmd
    cmd=("${spring}" "--isolation" "--write-dir" "${work_dir}")
    cmd=( "${cmd[@]}" "${ea[@]}" )

    __log "Run ${cmd[*]}" # note this ends up int $output when the caller redirects it.

    if [ "${mode}" == "full" ] || [ "${mode}" == "headless" ]; then
        set +e
        output=$(eval "${cmd[*]}" 2>&1)
        rc=$?
        set -e

        # TODO(Fast): Not sure why recoil always exits 139 in the current scenario.
        if [ "${rc}" -eq 139 ]; then
            rc=0
        fi
    elif [ "${mode}" == "direct" ]; then
        set +e
        eval "${cmd[*]}"
        rc=$?
        set -e

        # TODO(Fast): Not sure why recoil always exits 139 in the current scenario.
        if [ "${rc}" -eq 139 ]; then
            rc=0
        fi
    else
        log_error "Unknown mode: ${mode}"
        return 1
    fi

    printf "%s" "${output}"
    return "$rc"
}

# Some rules from: https://github.com/techannihilation/TA/blob/c932d28c9589f0ddb4efa4694dd25a684a6dc317/.github/workflows/validate-game.yml
recoil_check_error() {
    __require_cmd pcregrep
    __require_cmd grep

    local output="$1"
    local rc="$2"

    local has_check_error=false

    local matches

    matches=$(printf "%s" "${output}" | pcregrep -o1 '(Error in .*\(\): \[string \".*\"\]:\d+:.*)' || true)

    if [ -n "${matches}" ]; then
        has_check_error=true
        __log_error "${matches}"
    fi

    if ! printf "%s" "${output}" | grep -q 'Player UnnamedPlayer finished loading and is now ingame'; then
        has_check_error=true
        __log_error "Game failed to load"
    fi

    if printf "%s" "${output}" | grep -q "Internal Lua error: Call failure"; then
        has_check_error=true
        __log_error "Found a lua gadget with error in it"
    fi

    if printf "%s" "${output}" | grep -qE 'Error: Failed to load: [^\.]+\.lua'; then
        has_check_error=true
        __log_error "Found a lua gadget with error in it"
    fi

    if [ "${rc}" -eq 0 ] && [ "${has_check_error}" == true ]; then
        rc=1
    fi

    return "$rc"
}

recoil_remove_widget() {
    local widget_path="$1"

    __log "Removing widget: ${widget_path}"

    rm -f "${widget_path}"
}

recoil_run() {
    local mode="$1"
    local work_dir="$2"
    local repo="$3"
    local branch="$4"
    local version="$5"
    local map="$6"
    local settings="$7"
    local args="$8"
    local always_print="${9:-false}"

    version=$(recoil_version "${version}")

    recoil_download_engine "${work_dir}" "${version}"
    recoil_download_game "${work_dir}" "${repo}" "${branch}"
    recoil_download_map "${work_dir}" "${map}"

    recoil_write_settings "${work_dir}" "${settings}"

    if [ "${mode}" == "direct" ]; then
        recoil_run_engine "direct" "${work_dir}" "${version}" "${args}"
        return $?
    fi

    # shellcheck disable=SC2329
    __recoil_cleanup() {
        recoil_remove_widget "$1/packages/game.sdd/luaui/Widgets/__test.lua"
    }
    # shellcheck disable=SC2064
    trap "__recoil_cleanup \"${work_dir}\"" EXIT

    recoil_write_widget "${work_dir}/packages/game.sdd/luaui/Widgets/__test.lua" "${_inject_widget}"

    local output=""
    local rc=1

    output=$(recoil_run_engine "${mode}" "${work_dir}" "${version}" "${args}")
    rc=$?

    recoil_check_error "${output}" "${rc}"
    rc=$?

    if [ "${_log_silent}" == false ] || [ "${rc}" -ne 0 ] || [ "${always_print}" == true ]; then
        printf '%s\n' "${output}"
    fi

    return "$rc"
}

__main() {
    local mode="${1:-"help"}"
    local work_dir="${2:-"."}"

    local repo="${3:-$RECOIL_DEFAULT_GAME_REPO}"
    local branch="${4:-$RECOIL_DEFAULT_GAME_BRANCH}"
    local map_url="${5:-$RECOIL_DEFAULT_MAP_URL}"
    local version="${6:-""}"
    local args=""

    if [ "$#" -ge 7 ]; then
        local -a ea
        for ((i=7;i<=$#;i++)); do
            ea+=$(printf '%q' "${!i}")
        done
        args=$(__join " " "${ea[@]}")
    else
        args="${RECOIL_DEFAULT_ARGS}"
    fi
    
    mkdir -p "${work_dir}"
    work_dir=$(realpath "${work_dir}")
    
    local rc=1

    case "$mode" in
    "full-silent")
        recoil_run "full" "${work_dir}" "${repo}" "${branch}" "${version}" "${map_url}" "${RECOIL_DEFAULT_SETTINGS}" "${args}"
        rc=$?
        ;;
    "headless-silent")
        recoil_run "headless" "${work_dir}" "${repo}" "${branch}" "${version}" "${map_url}" "${RECOIL_DEFAULT_SETTINGS}" "${args}"
        rc=$?
        ;;
    "full")
        recoil_enable_log
        recoil_run "full" "${work_dir}" "${repo}" "${branch}" "${version}" "${map_url}" "${RECOIL_DEFAULT_SETTINGS}" "${args}"
        rc=$?
        ;;
    "headless")
        recoil_enable_log
        recoil_run "headless" "${work_dir}" "${repo}" "${branch}" "${version}" "${map_url}" "${RECOIL_DEFAULT_SETTINGS}" "${args}"
        rc=$?
        ;;
    "run")
        recoil_enable_log
        recoil_run "direct" "${work_dir}" "${repo}" "${branch}" "${version}" "${map_url}" "${RECOIL_DEFAULT_SETTINGS}" "${args}"
        rc=$?
        ;;
    *)
        printf "%s\n" "${_usage}" > /dev/stderr
        return 1
        ;;
    esac

    return ${rc}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    __main "$@"
    exit $?
fi
