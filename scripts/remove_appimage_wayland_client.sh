#!/usr/bin/env bash
# Post-process AppImages after Tauri/linuxdeploy builds them.
#
# 1. Remove the bundled libwayland-client.so.0 so the host's ABI-compatible copy
#    is resolved instead (required for EGL/Mesa on pure-Wayland systems).
# 2. Remove GStreamer plugin path overrides, since the AppImage does not bundle
#    GStreamer plugins (fixes "GStreamer element appsink not found").
# 3. Optionally embed update information and generate a .zsync delta file.
#
# Usage:
#   remove_appimage_wayland_client.sh <appimage-directory>
#
# Optional environment variables (may contain `{name}` / `{name_star}`, replaced
# with each AppImage's basename):
#   UPDATE_INFO  appimagetool `-u` value (e.g. "zsync|https://.../{name}.zsync")
#   ZSYNC_URL    full-download URL written into the generated .zsync file
#   VERSION      version string; enables `{name_star}` (basename with the
#                version replaced by `*`, for gh-releases-zsync patterns)
#
# Note: repacking swaps the AppImage's embedded runtime for appimagetool's own.
# This is harmless — both are backward-compatible type-2 runtimes.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <appimage-directory>" >&2
  exit 64
fi

APPIMAGE_DIR="$1"
UPDATE_INFO="${UPDATE_INFO:-}"
ZSYNC_URL="${ZSYNC_URL:-}"
VERSION="${VERSION:-}"

if [ ! -d "$APPIMAGE_DIR" ]; then
  echo "AppImage directory does not exist: $APPIMAGE_DIR" >&2
  exit 66
fi
# Resolve to an absolute path: the extraction subshell `cd`s away, so a relative
# path (as passed by the CI workflow) would no longer resolve.
APPIMAGE_DIR="$(cd "$APPIMAGE_DIR" && pwd)"

case "$(uname -m)" in
  x86_64|aarch64) APPIMAGE_ARCH="$(uname -m)" ;;
  *)
    echo "Unsupported AppImage architecture: $(uname -m)" >&2
    exit 69
    ;;
esac

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

APPIMAGETOOL="$WORK_DIR/appimagetool.AppImage"
curl --fail --location --silent --show-error \
  --output "$APPIMAGETOOL" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage"
chmod +x "$APPIMAGETOOL"
export APPIMAGE_EXTRACT_AND_RUN=1

shopt -s nullglob
APPIMAGES=("$APPIMAGE_DIR"/*.AppImage)
if [ "${#APPIMAGES[@]}" -eq 0 ]; then
  echo "No AppImages found in: $APPIMAGE_DIR" >&2
  exit 66
fi

for appimage in "${APPIMAGES[@]}"; do
  image_name="$(basename "$appimage")"
  image_work_dir="$WORK_DIR/${image_name}.work"
  mkdir "$image_work_dir"

  echo "==> Extracting ${image_name}"
  (
    cd "$image_work_dir"
    "$appimage" --appimage-extract >/dev/null
  )

  # Locate the bundled Wayland client library (the exact path varies by build,
  # so search rather than hardcoding usr/lib/).
  wayland_client="$(find "$image_work_dir/squashfs-root" -name 'libwayland-client.so.0' -print -quit)"
  if [ -z "$wayland_client" ]; then
    echo "Bundled libwayland-client.so.0 not found in ${image_name}" >&2
    exit 1
  fi
  echo "==> Removing bundled libwayland-client.so.0 from ${image_name}"
  rm -f "$wayland_client"

  # Remove GStreamer plugin path overrides (tauri#15665). The AppImage does not
  # bundle GStreamer plugins, so these overrides point at a non-existent
  # directory and break plugin discovery ("GStreamer element appsink not found").
  apprun_wrapped="$image_work_dir/squashfs-root/AppRun.wrapped"
  if [ -f "$apprun_wrapped" ]; then
    sed -i '/GST_PLUGIN_SYSTEM_PATH/d; /GST_PLUGIN_PATH/d' "$apprun_wrapped"
  fi
  for hook in "$image_work_dir/squashfs-root/apprun-hooks/"*.sh; do
    [ -f "$hook" ] || continue
    sed -i '/GST_PLUGIN_SYSTEM_PATH/d; /GST_PLUGIN_PATH/d' "$hook"
  done

  repack_args=(--no-appstream)
  if [ -n "$UPDATE_INFO" ]; then
    update_info="${UPDATE_INFO//\{name\}/$image_name}"
    if [ -n "$VERSION" ]; then
      name_star="${image_name/${VERSION}/*}"
      update_info="${update_info//\{name_star\}/$name_star}"
    fi
    repack_args+=(-u "$update_info")
  fi

  echo "==> Repacking ${image_name}"
  replacement="$image_work_dir/${image_name}.new"
  "$APPIMAGETOOL" "${repack_args[@]}" \
    "$image_work_dir/squashfs-root" "$replacement" >/dev/null
  chmod +x "$replacement"
  mv "$replacement" "$appimage"

  if [ -n "$ZSYNC_URL" ]; then
    zsync_url="${ZSYNC_URL//\{name\}/$image_name}"
    echo "==> Generating .zsync for ${image_name}"
    zsyncmake -u "$zsync_url" -o "$appimage.zsync" "$appimage"
  fi
done
