#!/bin/zsh
# ==============================================================================
# CryptoNotch Unified Release Automation
# ==============================================================================
# Usage:
#   ./scripts/release.sh <version> [title] [notes] [flags]
#
# Examples:
#   ./scripts/release.sh 1.4.0
#   ./scripts/release.sh 1.4.0 "Fluid Micro-Interactions"
#   ./scripts/release.sh 1.4.0 "Fluid Micro-Interactions" "Release notes..." --yes
#   ./scripts/release.sh 1.4.0 --dry-run
#
# Flags:
#   --dry-run       Perform build & verification without committing, pushing, or releasing
#   --yes, -y       Skip interactive confirmation prompt
#   --skip-tests    Skip 'swift test' pre-flight check
#   --skip-build    Skip xcodebuild & packaging if CryptoNotch.dmg already exists
#   --help, -h      Show this help documentation
# ==============================================================================

set -eo pipefail

SOURCE="$0"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Text styles
BOLD="\033[1m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
DIM="\033[2m"
RESET="\033[0m"

log_info()  { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
log_step()  { echo -e "  ${CYAN}▸${RESET} $1"; }
log_succ()  { echo -e "${GREEN}✔${RESET} ${BOLD}$1${RESET}"; }
log_warn()  { echo -e "${YELLOW}⚠${RESET} ${BOLD}$1${RESET}"; }
log_err()   { echo -e "${RED}✖${RESET} ${BOLD}$1${RESET}"; }

# Parse arguments
TARGET_VERSION=""
RELEASE_TITLE=""
RELEASE_NOTES=""
DRY_RUN=false
AUTO_CONFIRM=false
SKIP_TESTS=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --yes|-y)
            AUTO_CONFIRM=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help|-h)
            sed -n '2,20p' "$SOURCE" | sed 's/# //'
            exit 0
            ;;
        *)
            if [ -z "$TARGET_VERSION" ]; then
                TARGET_VERSION="$1"
            elif [ -z "$RELEASE_TITLE" ]; then
                RELEASE_TITLE="$1"
            elif [ -z "$RELEASE_NOTES" ]; then
                RELEASE_NOTES="$1"
            else
                log_warn "Unknown positional argument: $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$TARGET_VERSION" ]; then
    log_err "Error: Missing target version."
    echo "Usage: ./scripts/release.sh <version> [title] [notes] [flags]"
    exit 1
fi

# Clean version format (strip leading 'v' if passed, e.g. v1.4.0 -> 1.4.0)
TARGET_VERSION="${TARGET_VERSION#v}"
TAG_NAME="v${TARGET_VERSION}"

echo -e "\n${BOLD}${CYAN}🚀 CryptoNotch Release Orchestrator${RESET} ${DIM}(${TAG_NAME})${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Pre-Flight Checks
# ------------------------------------------------------------------------------
log_info "1. Running pre-flight system checks..."

# Check required commands
for cmd in git xcodebuild codesign hdiutil gh python3 jq; do
    if ! command -v "$cmd" &>/dev/null; then
        log_err "Missing required dependency: $cmd"
        exit 1
    fi
done
log_step "All CLI dependencies verified (git, xcodebuild, codesign, hdiutil, gh, python3, jq)."

# Locate Sparkle sign_update binary
SIGN_UPDATE=$(find . -name "sign_update" -type f -perm +111 2>/dev/null | head -n 1)
if [ -z "$SIGN_UPDATE" ]; then
    log_err "Could not locate Sparkle 'sign_update' binary. Run swift package resolve or build first."
    exit 1
fi
log_step "Found Sparkle signing tool: ${DIM}${SIGN_UPDATE}${RESET}"

# Verify git branch is main
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    log_warn "Current git branch is '${CURRENT_BRANCH}', not 'main'."
fi

# Check for existing tag
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    log_err "Tag ${TAG_NAME} already exists locally. Pick a new version or delete the existing tag."
    exit 1
fi
if git ls-remote --tags origin "refs/tags/${TAG_NAME}" | grep -q "$TAG_NAME"; then
    log_err "Tag ${TAG_NAME} already exists on remote 'origin'."
    exit 1
fi

# Determine current version and next build number
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0.0")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist 2>/dev/null || echo "1")
NEW_BUILD=$((CURRENT_BUILD + 1))

log_step "Current Version: ${BOLD}${CURRENT_VERSION}${RESET} (Build ${CURRENT_BUILD})"
log_step "Target Release:  ${BOLD}${TARGET_VERSION}${RESET} (Build ${NEW_BUILD})"

# Normalize release title to ensure it always includes "v${TARGET_VERSION} — "
if [ -z "$RELEASE_TITLE" ]; then
    RELEASE_TITLE="v${TARGET_VERSION} — Official Release"
elif [[ ! "$RELEASE_TITLE" =~ ^v[0-9] ]]; then
    RELEASE_TITLE="v${TARGET_VERSION} — ${RELEASE_TITLE}"
fi

# Default notes if not supplied: extract commits since last tag
if [ -z "$RELEASE_NOTES" ]; then
    PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$PREV_TAG" ]; then
        log_step "Generating release notes from commits since ${PREV_TAG}..."
        COMMITS=$(git log "${PREV_TAG}..HEAD" --no-merges --pretty=format:"- %s" | grep -v "chore(release)" | grep -v "chore(feed)" || echo "- Maintenance and stability enhancements")
    else
        COMMITS="- Initial public release"
    fi
    RELEASE_NOTES="$COMMITS"
fi

echo -e "\n${DIM}Release Title:${RESET} ${BOLD}${RELEASE_TITLE}${RESET}"
echo -e "${DIM}Release Notes Preview:${RESET}\n${RELEASE_NOTES}\n"

# Confirmation prompt unless --yes or --dry-run
if [ "$AUTO_CONFIRM" = false ] && [ "$DRY_RUN" = false ]; then
    read -p "Proceed with releasing ${TAG_NAME} (Build ${NEW_BUILD})? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Release aborted by user."
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# 2. Automated Testing
# ------------------------------------------------------------------------------
PUB_DATE=$(date "+%a, %d %b %Y %H:%M:%S %z")

if [ "$SKIP_TESTS" = true ]; then
    log_warn "Skipping unit tests (--skip-tests flag passed)."
else
    log_info "2. Executing unit test suite..."
    swift test
    log_succ "All unit tests passed successfully."
fi

# ------------------------------------------------------------------------------
# Dry-Run Simulation Mode
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    log_warn "DRY-RUN MODE ENABLED: Simulating planned release actions without modifying git or files."
    echo ""
    log_step "Would update Info.plist: CFBundleShortVersionString -> ${TARGET_VERSION}, CFBundleVersion -> ${NEW_BUILD}"
    log_step "Would update project.pbxproj: MARKETING_VERSION -> ${TARGET_VERSION}, CURRENT_PROJECT_VERSION -> ${NEW_BUILD}"
    if [ "$SKIP_BUILD" = false ]; then
        log_step "Would execute ./package.sh to compile Release binary, codesign Sparkle & App, and package DMG"
    fi
    log_step "Would sign CryptoNotch.dmg using: ${SIGN_UPDATE}"
    log_step "Would inject release item into appcast.xml with date '${PUB_DATE}'"
    log_step "Would re-sign appcast.xml using: ${SIGN_UPDATE}"
    log_step "Would create atomic commit 1: 'chore(release): bump version to ${TARGET_VERSION} (build ${NEW_BUILD})'"
    log_step "Would create atomic commit 2: 'chore(feed): update Sparkle appcast feed for ${TAG_NAME}'"
    log_step "Would tag release: ${TAG_NAME}"
    log_step "Would push to: origin main and origin ${TAG_NAME}"
    log_step "Would publish GitHub Release: ${TAG_NAME} (${RELEASE_TITLE}) with CryptoNotch.dmg"
    log_step "Would update Homebrew Tap: Verzional/homebrew-tap Casks/cryptonotch.rb"
    echo ""
    log_succ "Dry-run simulation complete. No files were modified."
    exit 0
fi

# ------------------------------------------------------------------------------
# 3. Version Bumping in Project Files
# ------------------------------------------------------------------------------
log_info "3. Updating project version files..."
log_step "Updating Info.plist (version ${TARGET_VERSION}, build ${NEW_BUILD})..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${TARGET_VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEW_BUILD}" Info.plist

log_step "Updating CryptoNotch.xcodeproj/project.pbxproj..."
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${TARGET_VERSION};/g" CryptoNotch.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" CryptoNotch.xcodeproj/project.pbxproj
log_succ "Project version files updated."

# ------------------------------------------------------------------------------
# 4. Build & Package DMG
# ------------------------------------------------------------------------------
if [ "$SKIP_BUILD" = true ] && [ -f "CryptoNotch.dmg" ]; then
    log_warn "Skipping build (--skip-build flag passed; using existing CryptoNotch.dmg)."
else
    log_info "4. Building and packaging CryptoNotch.dmg..."
    ./package.sh
    log_succ "CryptoNotch.dmg successfully built and signed."
fi

# ------------------------------------------------------------------------------
# 5. Sparkle EdDSA Signing & Appcast Generation
# ------------------------------------------------------------------------------
log_info "5. Generating Sparkle EdDSA signature and updating appcast.xml..."
SPARKLE_SIG_OUTPUT=$("$SIGN_UPDATE" CryptoNotch.dmg)
log_step "Sparkle signature output: ${DIM}${SPARKLE_SIG_OUTPUT}${RESET}"

DMG_SHA256=$(shasum -a 256 CryptoNotch.dmg | awk '{print $1}')
DMG_SIZE=$(stat -f%z CryptoNotch.dmg)
PUB_DATE=$(date "+%a, %d %b %Y %H:%M:%S %z")

# Convert markdown bullet points to HTML <li> items for appcast CDATA
NOTES_HTML=$(echo "$RELEASE_NOTES" | sed 's/^[*-] /  <li>/' | sed 's/$/<\/li>/')

# Safe insertion into appcast.xml via python3
python3 - << EOF
import sys

appcast_path = "appcast.xml"
version = "${TARGET_VERSION}"
build = "${NEW_BUILD}"
pub_date = "${PUB_DATE}"
sig_output = '${SPARKLE_SIG_OUTPUT}'
notes_html = '''${NOTES_HTML}'''

item_xml = f"""        <item>
            <title>CryptoNotch {version}</title>
            <pubDate>{pub_date}</pubDate>
            <sparkle:version>{build}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
<h2>CryptoNotch {version}</h2>
<ul>
{notes_html}
</ul>
            ]]></description>
            <enclosure url="https://github.com/Verzional/CryptoNotch/releases/download/v{version}/CryptoNotch.dmg" {sig_output} type="application/octet-stream"></enclosure>
        </item>
"""

with open(appcast_path, "r", encoding="utf-8") as f:
    content = f.read()

target = "<language>en</language>\n"
if target in content:
    content = content.replace(target, target + item_xml, 1)
else:
    # Fallback to inserting after <channel>
    target = "<channel>\n"
    content = content.replace(target, target + item_xml, 1)

with open(appcast_path, "w", encoding="utf-8") as f:
    f.write(content)

print("  ▸ Successfully injected item into appcast.xml")
EOF

log_step "Signing appcast.xml feed signatures with sign_update..."
"$SIGN_UPDATE" appcast.xml
log_succ "appcast.xml updated and signed."

# ------------------------------------------------------------------------------
# 6. Git Atomic Commits & Tagging
# ------------------------------------------------------------------------------
log_info "6. Committing changes and creating tag ${TAG_NAME}..."

git add Info.plist CryptoNotch.xcodeproj/project.pbxproj
if [ -f "README.md" ] && git status --porcelain README.md | grep -q "M"; then
    git add README.md
fi
git commit -m "chore(release): bump version to ${TARGET_VERSION} (build ${NEW_BUILD})"
log_step "Created version bump commit."

git add appcast.xml
git commit -m "chore(feed): update Sparkle appcast feed for ${TAG_NAME}"
log_step "Created appcast feed commit."

git tag -a "${TAG_NAME}" -m "Release ${TAG_NAME}"
log_succ "Tagged ${TAG_NAME}."

# ------------------------------------------------------------------------------
# 7. Push to Remote GitHub Repository
# ------------------------------------------------------------------------------
log_info "7. Pushing commits and tag to origin/main..."
git push origin main
git push origin "${TAG_NAME}"
log_succ "Pushed to origin."

# ------------------------------------------------------------------------------
# 8. GitHub Release & Asset Upload
# ------------------------------------------------------------------------------
log_info "8. Creating GitHub Release ${TAG_NAME}..."
gh release create "${TAG_NAME}" CryptoNotch.dmg \
    --title "${RELEASE_TITLE}" \
    --notes "${RELEASE_NOTES}"
log_succ "GitHub Release published: https://github.com/Verzional/CryptoNotch/releases/tag/${TAG_NAME}"

# ------------------------------------------------------------------------------
# 9. Homebrew Tap Cask Update
# ------------------------------------------------------------------------------
log_info "9. Updating Homebrew Tap (Verzional/homebrew-tap)..."
TAP_REPO="Verzional/homebrew-tap"
CASK_PATH="Casks/cryptonotch.rb"

# Fetch current cask file metadata from GitHub API
TAP_SHA=$(gh api "repos/${TAP_REPO}/contents/${CASK_PATH}" --jq '.sha' 2>/dev/null || echo "")
if [ -n "$TAP_SHA" ]; then
    
    NEW_CASK_CONTENT=$(cat << EOF
cask "cryptonotch" do
  version "${TARGET_VERSION}"
  sha256 "${DMG_SHA256}"

  url "https://github.com/Verzional/CryptoNotch/releases/download/v#{version}/CryptoNotch.dmg"
  name "CryptoNotch"
  desc "Real-time cryptocurrency ticker in your MacBook notch"
  homepage "https://github.com/Verzional/CryptoNotch"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "CryptoNotch.app"

  zap trash: "~/Library/Preferences/com.verzional.CryptoNotch.plist"
end
EOF
)
    NEW_CASK_B64=$(echo "$NEW_CASK_CONTENT" | base64)
    
    gh api --method PUT "repos/${TAP_REPO}/contents/${CASK_PATH}" \
        --field message="chore(cask): bump cryptonotch to ${TARGET_VERSION}" \
        --field content="$NEW_CASK_B64" \
        --field sha="$TAP_SHA" > /dev/null
    
    log_succ "Homebrew Tap cask updated in ${TAP_REPO}."
else
    log_warn "Could not access ${TAP_REPO}/${CASK_PATH} via gh api. Cask must be updated manually."
fi

# ------------------------------------------------------------------------------
# 10. Local App Refresh
# ------------------------------------------------------------------------------
log_info "10. Refreshing local installation at /Applications/CryptoNotch.app..."
if [ -d "/Applications/CryptoNotch.app" ] && [ -d "CryptoNotch.app" ]; then
    pkill -x "CryptoNotch" 2>/dev/null || true
    sleep 0.5
    rm -rf "/Applications/CryptoNotch.app"
    cp -R "CryptoNotch.app" "/Applications/"
    open "/Applications/CryptoNotch.app"
    log_succ "CryptoNotch ${TARGET_VERSION} installed and running locally."
fi

echo -e "\n${BOLD}${GREEN}🎉 Release ${TAG_NAME} completed successfully!${RESET}\n"
