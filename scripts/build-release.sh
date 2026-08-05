#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 vX.Y.Z" >&2
    exit 1
fi

readonly TAG_VERSION="$1"
readonly VERSION_NO_V="${TAG_VERSION#v}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_FILE="${REPO_ROOT}/project.yml"
readonly DERIVED_DATA_DIR="${REPO_ROOT}/DerivedData"
readonly APP_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/Focally.app"
readonly OUTPUT_DIR="${REPO_ROOT}/build"
readonly DMG_PATH="${OUTPUT_DIR}/Focally-${TAG_VERSION}.dmg"

read_project_setting() {
    local setting="$1"
    awk -v setting="${setting}" '
        $1 == setting ":" {
            value = $2
            gsub(/"/, "", value)
            print value
            exit
        }
    ' "${PROJECT_FILE}"
}

readonly MARKETING_VERSION="$(read_project_setting MARKETING_VERSION)"
readonly CURRENT_PROJECT_VERSION="$(read_project_setting CURRENT_PROJECT_VERSION)"

if [[ -z "${MARKETING_VERSION}" || -z "${CURRENT_PROJECT_VERSION}" ]]; then
    echo "Could not read release versions from project.yml" >&2
    exit 1
fi

if [[ "${VERSION_NO_V}" != "${MARKETING_VERSION}" ]]; then
    echo "Tag version ${VERSION_NO_V} does not match MARKETING_VERSION ${MARKETING_VERSION}" >&2
    exit 1
fi

command -v xcodegen >/dev/null || { echo "xcodegen is required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "xcodebuild is required" >&2; exit 1; }
command -v hdiutil >/dev/null || { echo "hdiutil is required" >&2; exit 1; }

cd "${REPO_ROOT}"
xcodegen generate
xcodebuild \
    -project Focally.xcodeproj \
    -scheme Focally \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

if [[ ! -d "${APP_PATH}" ]]; then
    echo "Built app not found at ${APP_PATH}" >&2
    exit 1
fi

readonly APP_INFO_PLIST="${APP_PATH}/Contents/Info.plist"
readonly BUILT_MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_INFO_PLIST}")"
readonly BUILT_PROJECT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${APP_INFO_PLIST}")"

if [[ "${BUILT_MARKETING_VERSION}" != "${MARKETING_VERSION}" ]]; then
    echo "Built app version ${BUILT_MARKETING_VERSION} does not match ${MARKETING_VERSION}" >&2
    exit 1
fi

if [[ "${BUILT_PROJECT_VERSION}" != "${CURRENT_PROJECT_VERSION}" ]]; then
    echo "Built app build ${BUILT_PROJECT_VERSION} does not match ${CURRENT_PROJECT_VERSION}" >&2
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
readonly STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/focally-release.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

cp -R "${APP_PATH}" "${STAGING_DIR}/Focally.app"
ln -s /Applications "${STAGING_DIR}/Applications"
rm -f "${DMG_PATH}"
hdiutil create \
    -volname Focally \
    -srcfolder "${STAGING_DIR}" \
    -format UDZO \
    -ov \
    "${DMG_PATH}"

echo "Created ${DMG_PATH}"
shasum -a 256 "${DMG_PATH}"
