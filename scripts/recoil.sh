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
#
# This is highly customizable and modular. Think it's easy to understand and adopt.
#
#

_version="2025-11-13"
_help="__cmd__ is a helper to setup a test environment for mods/widgets and test them with spring/spring-headless.

Usage: __cmd__ <full|headless|direct> <directory> [--recoil-version] [--repo] [--git-branch] [--game] [--map-url] [--map] [-q|--quiet] [-h|--help]

Modes:

    - full           : Interactive recoil with an injected widget (\"spring\")
    - headless       : None-interactive recoil (\"spring-headless\")
    - direct         : Interactive w/o the widget (\"spring\")

Options:
    --recoil-version : Recoil Release (default: latest github release)
    --repo           : git repo or rapid tag (default: __RECOIL_DEFAULT_GAME_REPO__)
    --git-branch     : The branch (default: __RECOIL_DEFAULT_GAME_BRANCH__)
    --game           : The game/mod (default: __RECOIL_DEFAULT_GAME__)
    --map-url        : Map download URL (default: __RECOIL_DEFAULT_MAP_URL__)
    --map            : Map to use (default: __RECOIL_DEFAULT_MAP__)
    -q, --quiet      : Quiet mode, print's only on error, print's the output of recoil on error as well
    -v, --version    : Print's the version
    -h, --help       : Print's the help

Funtionality:

    - downloads (if not there):
        - recoil (latest version auto-detected if wanted)
        - game/mod (using git first if fails it tries pr-downloader/rapid)
        - A map
    - customizes the game with a widget to enable any other widget and quit the game after x seconds
        - This is disabled for pr-downloader games, it can't modify those packages atm.
        - This is disabled for \"direct\" games, you wanna test/play not quit.
    - writes a custom springsettings.cfg
    - run\'s spring or spring-headless
    - checks the output for common errors (grep + pcregrep)
    - removes the custom widget
    - print\'s the output on error in quiet mode and always else

Examples:

    # Run headless in silent mode (only output on error with complete log)
    $ __cmd__ -q headless test/bar

    # Run the game with script defaults
    $ __cmd__ direct test/bar

    # Run headless with a local git repo and latest stable recoil
    $ __cmd__ headless test/bar-local --repo=../Beyond-All-Reason

    # Run a rc version of recoil
    $ __cmd__ headless test/bar-local --recoil-version=2025.06.09 --repo=../Beyond-All-Reason

    # Run a rc version of recoil with official bar (using pr-downloader)
    $ __cmd__ direct test/byar-test --recoil-version=2025.06.09 --repo=byar:test --game='Beyond All Reason test-28880-bf7ac6e'

    # Run TechA :)
    $ __cmd__ direct test/techa --repo https://github.com/techannihilation/TA.git --game 'Tech Annihilation \$VERSION' --map 'Techno Lands Final 26.0' --map-url http://www.hakora.xyz/files/springrts/maps/techno_lands_final_26.0.sd7

Dependencies:

    getopt, pcregrep, grep, git, 7z, curl, sed, realpath

    No other external deps.

As a library:

    See: https://github.com/00fast00/overwatch-widget/blob/7834c1de3743cce838767d5fb368e78fd340327d/scripts/build.sh#L66

Copyright:

    - Fast - The Unlicense
"

#
##### Config
#
RECOIL_DEFAULT_GAME_REPO=${RECOIL_DEFAULT_GAME_REPO:-"https://github.com/beyond-all-reason/Beyond-All-Reason.git"}
RECOIL_DEFAULT_GAME_BRANCH=${RECOIL_DEFAULT_GAME_BRANCH:-"master"}
RECOIL_DEFAULT_MAP_URL=${RECOIL_DEFAULT_MAP_URL:-"https://files-cdn.beyondallreason.dev/file/21028d5855cbaf0f413b5c6c7cd44d3e/full_metal_plate_1.7.sd7"}
RECOIL_DEFAULT_MAP=${RECOIL_DEFAULT_MAP:-"Full Metal Plate 1.7"}
RECOIL_DEFAULT_GAME=${RECOIL_DEFAULT_GAME:-"Beyond All Reason \$VERSION"}

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

RECOIL_SCRIPT_TEMPLATE=${RECOIL_SCRIPT_TEMPLATE:-"
[game]
{
[player0]
{
team=0;
name=UnnamedPlayer;
}
[team0]
{
allyteam=0;
teamleader=0;
}
[allyteam0]
{
numallies=0;
}
[modoptions]
{
minimalsetup=1;
}
gametype=__GAME__;
ishost=1;
mapname=__MAP__;
myplayername=UnnamedPlayer;
}
"}

RECOIL_PRD_HTTP_SEARCH_URL=${RECOIL_PRD_HTTP_SEARCH_URL:-"https://files-cdn.beyondallreason.dev/find"}
RECOIL_PRD_RAPID_USE_STREAMER=${RECOIL_PRD_RAPID_USE_STREAMER:-"false"}
RECOIL_PRD_RAPID_REPO_MASTER=${RECOIL_PRD_RAPID_REPO_MASTER:-"https://repos-cdn.beyondallreason.dev/repos.gz"}

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
_log_error_buff=""
###

###
# Templates
_inject_widget=$(
    cat <<EOF
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
function __join {
    local IFS="$1"
    shift
    echo "$*"
}

__log() {
    if [ "${_log_silent}" == true ]; then
        return
    fi

    printf "SCRIPT: %s\n" "$*" >&1
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

__sed_template() {
    __require_cmd sed

    local input=$1
    local -n subs_ref=$2

    local -a sedopts=()
    for k in "${!subs_ref[@]}"; do
        sedopts+=("-e" "s#${k}#${subs_ref[$k]}#g")
    done

    printf "%s" "${input}" | sed "${sedopts[@]}"
}

__incase_path() {
    local work_dir=$1
    local input=$2

    local d

    d=$(find "${work_dir}" -ipath "$(dirname "${work_dir}/${input}")" | head -n 1)
    if [ -z "${d}" ]; then
        return 1
    fi

    printf "%s" "${d}/$(basename "${input}")"

    return 0
}

#
# Code
#
recoil_enable_log() {
    _log_silent=false
}

recoil_log_error_buff() {
    _log_error_buff+=$(printf -- "ERROR: %s\n" "$*")
}

recoil_print_error_buff() {
    if [ "${#_log_error_buff}" -ge 1 ]; then
        printf "%s\n" "${_log_error_buff}" >&2
        _log_error_buff=""
    fi
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
# Download game if needed.
#
recoil_download_game() {
    __require_cmd git

    local work_dir=$1
    local repo=$2
    local branch=$3
    local recoil_version=$4

    local packages_dir="${work_dir}/packages"
    if [ ! -d "${packages_dir}" ]; then
        mkdir -p "${packages_dir}"
    fi

    if [ ! -d "${packages_dir}/game.sdd" ]; then
        __log "Downloading game: ${repo} (trying git first)"

        local output
        if output=$(git clone --depth 1 -b "${branch}" "${repo}" "${packages_dir}/game.sdd" 2>&1); then
            return 0
        fi

        local pr_downloader
        pr_downloader="${work_dir}/engine/recoil_${recoil_version}/pr-downloader"
        if [ -x "${pr_downloader}" ]; then
            __log "Downloading game from rapid: ${repo}"
            if PRD_HTTP_SEARCH_URL="${RECOIL_PRD_HTTP_SEARCH_URL}" \
                PRD_RAPID_USE_STREAMER="${RECOIL_PRD_RAPID_USE_STREAMER}" \
                PRD_RAPID_REPO_MASTER="${RECOIL_PRD_RAPID_REPO_MASTER}" \
                ${pr_downloader} --filesystem-writepath "${work_dir}" --download-game "${repo}"; then
                return 0
            fi

        fi

        # If we are here both git and pr-downloader failed
        __log_error "${output}"

        return 1
    fi

    return 0
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
        __log "Downloading map: ${url} (trying curl first)"

        local output
        if output=$(curl --fail --show-error --silent --location "${url}" -o "${map_dir}/${map_file}" 2>&1); then
            return 0
        fi

        local pr_downloader
        pr_downloader="${work_dir}/engine/recoil_${recoil_version}/pr-downloader"
        if [ -x "${pr_downloader}" ]; then
            __log "Downloading map from rapid: ${url}"
            if PRD_HTTP_SEARCH_URL="${RECOIL_PRD_HTTP_SEARCH_URL}" \
                PRD_RAPID_USE_STREAMER="${RECOIL_PRD_RAPID_USE_STREAMER}" \
                PRD_RAPID_REPO_MASTER="${RECOIL_PRD_RAPID_REPO_MASTER}" \
                ${pr_downloader} --filesystem-writepath "${work_dir}" --download-map "${url}"; then
                return 0
            fi

        fi

        # If we are here both curl and pr-downloader failed
        __log_error "${output}"

        return 1
    fi

    return 0
}

recoil_write_widget() {
    local work_dir="$1"
    local widget_path="$2"
    local content="$3"

    __log "Writing widget: ${widget_path}"

    # Fix "Widgets (BAR)" vs "widgets (TechA)"
    widget_path=$(__incase_path "${work_dir}" "${widget_path}")

    local tmp
    tmp=$(mktemp "${widget_path}.XXXXXX")
    printf '%s' "${content}" >"${tmp}"

    mv -f "${tmp}" "${widget_path}"
}

recoil_remove_widget() {
    local work_dir="$1"
    local widget_path="$2"

    __log "Removing widget: ${widget_path}"

    # Fix "Widgets" vs "widgets"
    widget_path=$(__incase_path "${work_dir}" "${widget_path}")

    rm -f "${widget_path}"
}

recoil_write_script() {
    local work_dir="$1"
    local script_game="$2"
    local script_map="$3"

    local script_path="${work_dir}/_script.txt"

    __log "Writing script: ${script_path}: game=${script_game} map=${script_map}"

    local -A subs=(
        ["__GAME__"]="${script_game}"
        ["__MAP__"]="${script_map}"
    )

    local content
    content=$(__sed_template "${RECOIL_SCRIPT_TEMPLATE}" subs)

    local tmp
    tmp=$(mktemp "${script_path}.XXXXXX")
    printf '%s' "${content}" >"${tmp}"

    mv -f "${tmp}" "${script_path}"
}

recoil_write_settings() {
    local work_dir="$1"

    __log "Writing ${work_dir}/springsettings.cfg"

    local tmp
    tmp=$(mktemp "${work_dir}/springsettings.cfg.XXXXXX")
    printf '%s' "${RECOIL_DEFAULT_SETTINGS}" >"${tmp}"

    mv -f "${tmp}" "${work_dir}/springsettings.cfg"
}

recoil_run_engine() {
    local mode="$1" # full|headless|direct
    local work_dir="$2"
    local version="$3"
    local args="$4"
    local always_print="${5:-false}"

    local output=""
    local rc=1

    local spring="${work_dir}/engine/recoil_${version}/spring-headless"

    if [ "${mode}" != "headless" ]; then
        spring="${work_dir}/engine/recoil_${version}/spring"
    fi

    local script_path="${work_dir}/_script.txt"

    local old_IFS=$IFS
    local -a ea
    IFS=" " read -r -a ea <<<"${args}"
    IFS=$old_IFS

    local -a cmd
    cmd=("${spring}" "--isolation" "--nocolor" "--write-dir" "${work_dir}")
    cmd=("${cmd[@]}" "${ea[@]}")
    cmd+=("${script_path}")

    __log "Run $(__join " " "${cmd[@]}")" # note this ends up int $output when the caller redirects it.

    if [ "${_log_silent}" == true ] && [ "${always_print}" == false ] && [ "${mode}" != "direct" ]; then
        output=$(nohup "${cmd[@]}" 2>&1)
        rc=$?
    else
        output=$(nohup "${cmd[@]}" 2>&1 | tee -i -a /dev/tty)
        rc=$?
    fi

    # TODO(Fast): Not sure why recoil always exits 139 in the current scenario.
    if [ "${rc}" -eq 139 ]; then
        rc=0
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
        recoil_log_error_buff "${matches}"
    fi

    if ! printf "%s" "${output}" | grep -q 'Player UnnamedPlayer finished loading and is now ingame'; then
        has_check_error=true
        recoil_log_error_buff "Game failed to load"
    fi

    if printf "%s" "${output}" | grep -q "Internal Lua error: Call failure"; then
        has_check_error=true
        recoil_log_error_buff "Found a lua gadget with error in it"
    fi

    if printf "%s" "${output}" | grep -qE 'Error: Failed to load: [^\.]+\.lua'; then
        has_check_error=true
        recoil_log_error_buff "Found a lua gadget with error in it"
    fi

    if [ "${rc}" -eq 0 ] && [ "${has_check_error}" == true ]; then
        rc=1
    fi

    return "$rc"
}

# recoil_run "${run_mode}" "${work_dir}" "${repo}" "${branch}" "${version}" "${map_url}" "${script_game}" "${script_map}" "${args}" true
recoil_run() {
    local mode="$1"
    local work_dir="$2"
    local repo="$3"
    local branch="$4"
    local version="$5"
    local map_url="$6"
    local script_game="$7"
    local script_map="$8"
    local args="${9:-""}"
    local always_print="${10:-false}"

    version=$(recoil_version "${version}")

    recoil_download_engine "${work_dir}" "${version}"

    set +e
    recoil_download_game "${work_dir}" "${repo}" "${branch}" "${version}"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        return $rc
    fi

    set +e
    recoil_download_map "${work_dir}" "${map_url}"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        return $rc
    fi

    recoil_write_script "${work_dir}" "${script_game}" "${script_map}"
    recoil_write_settings "${work_dir}"

    if [ "${mode}" != "direct" ] && [ -d "${work_dir}/packages/game.sdd" ]; then
        # shellcheck disable=SC2329
        __recoil_cleanup() {
            recoil_remove_widget "$1" "packages/game.sdd/luaui/Widgets/__test.lua"
            recoil_print_error_buff
        }
        # shellcheck disable=SC2064
        trap "__recoil_cleanup \"${work_dir}\"" EXIT

        recoil_write_widget "${work_dir}" "packages/game.sdd/luaui/Widgets/__test.lua" "${_inject_widget}"
    else
        trap "recoil_print_error_buff" EXIT
    fi

    # set -x

    local output=""
    local rc=1

    set +e
    output=$(recoil_run_engine "${mode}" "${work_dir}" "${version}" "${args}" "${always_print}")
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
        recoil_check_error "${output}" "${rc}"
        rc=$?
    fi

    if [ "${_log_silent}" == false ] && [ "${rc}" -ne 0 ]; then
        printf '%s\n' "${output}"
    fi

    return "$rc"
}

__main() {
    __require_cmd getopt
    __require_cmd pcregrep
    __require_cmd grep
    __require_cmd git
    __require_cmd 7z
    __require_cmd curl
    __require_cmd sed
    __require_cmd realpath

    # https://labex.io/tutorials/shell-bash-getopt-391993
    local OPTS
    if ! OPTS=$(getopt -o hvq --long help,version,quiet,recoil-version:,repo:,git-branch:,game:,map-url:,map: -- "$@"); then
        __log_error "While parsing options"
        exit 1
    fi

    ## Reset the positional parameters to the parsed options
    eval set -- "$OPTS"

    local help=false
    local version=false
    local quiet=false
    local recoil_version=""
    local repo="${RECOIL_DEFAULT_GAME_REPO}"
    local branch="${RECOIL_DEFAULT_GAME_BRANCH}"
    local script_game="${RECOIL_DEFAULT_GAME}"
    local script_map="${RECOIL_DEFAULT_MAP}"
    local map_url="${RECOIL_DEFAULT_MAP_URL}"

    ## Process the options
    while true; do
        case "$1" in
        -h | --help)
            help=true
            shift
            ;;
        -v | --version)
            version=true
            shift
            ;;
        -q | --quiet)
            quiet=true
            shift
            ;;

        --recoil-version)
            recoil_version="$2"
            shift 2
            ;;
        --repo)
            repo="$2"
            shift 2
            ;;
        --git-branch)
            branch="$2"
            shift 2
            ;;
        --game)
            script_game="$2"
            shift 2
            ;;
        --map)
            script_map="$2"
            shift 2
            ;;
        --map-url)
            map_url="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            __log_error "Unknown option: $*"
            exit 1
            ;;
        esac
    done

    if [ "${version}" == true ]; then
        printf "%s version %s\n" "${0}" "${_version}"
        exit 0
    fi

    local known_modes="full:headless:direct"
    local mode
    local work_dir

    if [ $# -lt 2 ]; then
        help=true
    else
        mode="${1}"
        shift
        work_dir="${1}"
        shift

        if [[ ":$known_modes:" != *:$mode:* ]]; then
            help=true
        fi
    fi

    if [ "${help}" == true ]; then
        # shellcheck disable=SC2034
        local -A subs=(
            ["__cmd__"]="${0}"
            ["__RECOIL_DEFAULT_GAME_REPO__"]="${RECOIL_DEFAULT_GAME_REPO}"
            ["__RECOIL_DEFAULT_GAME_BRANCH__"]="${RECOIL_DEFAULT_GAME_BRANCH}"
            ["__RECOIL_DEFAULT_GAME__"]="${RECOIL_DEFAULT_GAME}"
            ["__RECOIL_DEFAULT_MAP_URL__"]="${RECOIL_DEFAULT_MAP_URL}"
            ["__RECOIL_DEFAULT_MAP__"]="${RECOIL_DEFAULT_MAP}"
        )

        local content=""
        content=$(__sed_template "${_help}" subs)

        printf "%s\n" "${content}"
        exit 0
    fi

    mkdir -p "${work_dir}"
    work_dir=$(realpath "${work_dir}")

    if [[ "${quiet}" != true ]] || [ "$mode" == "direct" ]; then
        recoil_enable_log
    fi

    local rc=1
    recoil_run "${mode}" "${work_dir}" "${repo}" "${branch}" "${recoil_version}" "${map_url}" "${script_game}" "${script_map}" "${@}"
    rc=$?

    return ${rc}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    __main "$@"
    exit $?
fi
