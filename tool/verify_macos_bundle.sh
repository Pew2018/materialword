#!/usr/bin/env bash
#
# Verify a built MaterialWord.app before it is handed to a user.
#
# The lesson behind this script: `flutter build macos --release` succeeding
# says nothing about whether the bundle can *start*. Phase 2 shipped a bundle
# that was structurally perfect, signed, correctly zipped — and launchd refused
# to spawn it because the signature carried `keychain-access-groups` without a
# provisioning profile to authorise it. Finder reported only
# "应用程序 MaterialWord.app 无法打开".
#
# So this script checks the things that actually decide whether a double-click
# works, including a real LaunchServices launch (the same code path Finder uses,
# unlike exec-ing the binary from a shell, which fails for sandboxed bundles).
#
# Usage:
#   tool/verify_macos_bundle.sh --app path/to/MaterialWord.app [options]
#
# Options:
#   --app PATH          The .app bundle to verify (required unless --zip).
#   --zip PATH          Also verify the distributable ZIP: extract it fresh and
#                       check the signature/structure survived the round trip.
#   --expect-arch A     arm64 | x86_64 | universal (default: universal)
#   --launch            Perform a real launch test via LaunchServices.
#   --launch-timeout N  Seconds the app must stay alive (default 12).
#   --allow-gui-skip    Treat "no GUI session" as a skip instead of a failure.
#   --report PATH       Append a machine readable summary to PATH.
#
# Exit status: 0 only when every executed check passed and no check failed.
# Skipped checks never masquerade as passed: they are printed as SKIP and
# counted in the summary.

set -uo pipefail

APP=""
ZIP=""
EXPECT_ARCH="universal"
DO_LAUNCH=0
LAUNCH_TIMEOUT=12
ALLOW_GUI_SKIP=0
REPORT=""

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILURES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --zip) ZIP="$2"; shift 2 ;;
    --expect-arch) EXPECT_ARCH="$2"; shift 2 ;;
    --launch) DO_LAUNCH=1; shift ;;
    --launch-timeout) LAUNCH_TIMEOUT="$2"; shift 2 ;;
    --allow-gui-skip) ALLOW_GUI_SKIP=1; shift ;;
    --report) REPORT="$2"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$APP" ] && [ -z "$ZIP" ]; then
  echo "error: --app or --zip is required" >&2
  exit 2
fi

pass() { printf 'PASS  %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() {
  printf 'FAIL  %s\n' "$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURES+=("$1")
}
skip() { printf 'SKIP  %s\n' "$1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }

section() { printf '\n== %s ==\n' "$1"; }

plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }

# ---------------------------------------------------------------------------
# 1-7: checks on the bundle itself
# ---------------------------------------------------------------------------
verify_bundle() {
  local app="$1"
  local label="${2:-bundle}"

  section "$label: bundle structure"

  # 1. The bundle exists and looks like a bundle.
  if [ -d "$app" ] && [ -d "$app/Contents" ]; then
    pass "1. bundle exists: $app"
  else
    fail "1. bundle missing or not a bundle: $app"
    return
  fi

  # 2. Info.plist is a valid plist and carries the required keys.
  local exec_name bundle_id min_os short_ver
  if plutil -lint "$app/Contents/Info.plist" >/dev/null 2>&1; then
    pass "2a. Info.plist is a valid plist"
  else
    fail "2a. Info.plist is not a valid plist"
  fi
  exec_name="$(plist "$app" CFBundleExecutable)"
  bundle_id="$(plist "$app" CFBundleIdentifier)"
  min_os="$(plist "$app" LSMinimumSystemVersion)"
  short_ver="$(plist "$app" CFBundleShortVersionString)"
  if [ -n "$exec_name" ] && [ -n "$bundle_id" ]; then
    pass "2b. CFBundleExecutable=$exec_name CFBundleIdentifier=$bundle_id version=${short_ver:-?} minOS=${min_os:-?}"
  else
    fail "2b. Info.plist is missing CFBundleExecutable or CFBundleIdentifier"
    return
  fi
  if [ "$bundle_id" = "com.pew2018.materialword" ]; then
    pass "2c. bundle identifier unchanged (user data location stays valid)"
  else
    fail "2c. bundle identifier changed to '$bundle_id' — existing user data would be orphaned"
  fi

  # 3. The executable exists, is executable, and is the one from Info.plist.
  local exe="$app/Contents/MacOS/$exec_name"
  if [ -f "$exe" ] && [ -x "$exe" ]; then
    pass "3. executable present and +x: Contents/MacOS/$exec_name"
  else
    fail "3. executable missing or not executable: $exe"
    return
  fi

  # 4. Architecture matches the promise made in build-info.
  local archs
  archs="$(lipo -archs "$exe" 2>/dev/null)"
  case "$EXPECT_ARCH" in
    universal)
      if [ "$(echo "$archs" | wc -w | tr -d ' ')" -ge 2 ]; then
        pass "4. Mach-O architectures: $archs (universal)"
      else
        fail "4. expected a universal binary, got: ${archs:-unknown}"
      fi
      ;;
    *)
      if echo " $archs " | grep -q " $EXPECT_ARCH "; then
        pass "4. Mach-O architectures: $archs (contains $EXPECT_ARCH)"
      else
        fail "4. expected $EXPECT_ARCH, got: ${archs:-unknown}"
      fi
      ;;
  esac

  # 5. Frameworks are complete: every embedded framework resolves, and every
  #    @rpath dependency of the main binary exists on disk.
  local fw_missing=0 fw_count=0
  while IFS= read -r fw; do
    fw_count=$((fw_count + 1))
    if [ ! -e "$fw" ]; then
      fail "5a. framework does not resolve (broken symlink): $fw"
      fw_missing=1
    fi
  done < <(find "$app/Contents/Frameworks" -maxdepth 1 -name '*.framework' 2>/dev/null)
  if [ "$fw_count" -eq 0 ]; then
    fail "5a. no frameworks embedded — the app cannot run a Dart engine"
  elif [ "$fw_missing" -eq 0 ]; then
    pass "5a. $fw_count embedded frameworks resolve"
  fi

  local dep_missing=0 dep_checked=0
  while IFS= read -r dep; do
    dep_checked=$((dep_checked + 1))
    # @rpath/Foo.framework/Versions/A/Foo -> Contents/Frameworks/...
    local rel="${dep#@rpath/}"
    if [ -e "$app/Contents/Frameworks/$rel" ]; then
      continue
    fi
    if [ -e "$app/Contents/Frameworks/$(basename "$dep")" ]; then
      continue
    fi
    fail "5b. missing dynamic dependency: $dep"
    dep_missing=1
  done < <(otool -L "$exe" 2>/dev/null | awk '/@rpath/{print $1}')
  if [ "$dep_missing" -eq 0 ]; then
    pass "5b. all @rpath dependencies resolve ($dep_checked checked)"
  fi

  if [ -n "$(find "$app" -type l 2>/dev/null | head -1)" ]; then
    pass "5c. framework symlinks preserved ($(find "$app" -type l | wc -l | tr -d ' ') links)"
  else
    fail "5c. no symlinks inside the bundle — the ZIP step flattened framework layout"
  fi

  # 6. Code signature integrity (this hashes every sealed resource and link).
  local verify_out
  if verify_out="$(codesign --verify --deep --strict --verbose=2 "$app" 2>&1)"; then
    pass "6. codesign --verify --deep --strict"
  else
    fail "6. codesign verification failed: $(echo "$verify_out" | tail -3 | tr '\n' ' ')"
  fi

  # 7. No restricted entitlement that this signature cannot authorise.
  #    `keychain-access-groups` without a provisioning profile is exactly what
  #    made launchd refuse to spawn the Phase 2 build.
  local ents
  ents="$(codesign -d --entitlements :- "$app" 2>/dev/null)"
  local has_profile=0
  [ -f "$app/Contents/embedded.provisionprofile" ] && has_profile=1

  local restricted_found=0
  for key in keychain-access-groups com.apple.security.application-groups \
             com.apple.application-identifier; do
    if echo "$ents" | grep -q "<key>$key</key>"; then
      if [ "$has_profile" -eq 0 ]; then
        fail "7. unauthorised restricted entitlement: $key (no provisioning profile)"
        restricted_found=1
      else
        pass "7. restricted entitlement $key is backed by a provisioning profile"
      fi
    fi
  done
  if echo "$ents" | grep -q "<key>com.apple.developer."; then
    if [ "$has_profile" -eq 0 ]; then
      fail "7. com.apple.developer.* entitlement without a provisioning profile"
      restricted_found=1
    fi
  fi
  if [ "$restricted_found" -eq 0 ]; then
    pass "7. no unauthorised restricted entitlements"
  fi

  # Release hygiene: a shipped bundle must not be debuggable.
  if echo "$ents" | grep -q "<key>com.apple.security.get-task-allow</key>"; then
    fail "7b. get-task-allow present in a release bundle (must be stripped)"
  else
    pass "7b. get-task-allow absent"
  fi

  # The entitlements we still need must be there, or features break silently.
  for key in com.apple.security.app-sandbox com.apple.security.network.client \
             com.apple.security.files.user-selected.read-write; do
    if echo "$ents" | grep -q "<key>$key</key>"; then
      pass "7c. keeps $key"
    else
      fail "7c. lost required entitlement: $key"
    fi
  done

  printf 'INFO  signature: %s\n' "$(codesign -dv "$app" 2>&1 | awk -F= '/^Signature/{print $2}')"
  printf 'INFO  team: %s\n' "$(codesign -dv "$app" 2>&1 | awk -F= '/^TeamIdentifier/{print $2}')"
  printf 'INFO  provisioning profile: %s\n' \
    "$([ "$has_profile" -eq 1 ] && echo present || echo none)"
  printf 'INFO  min macOS: %s\n' "${min_os:-unknown}"
  # An un-notarised ad-hoc build is *expected* to be refused by Gatekeeper on a
  # machine with default security settings. That is a distribution limitation,
  # not a broken signature — the checks above decide launchability.
  if spctl --assess --type execute "$app" >/dev/null 2>&1; then
    printf 'INFO  spctl: accepted\n'
  else
    printf 'INFO  spctl: rejected — expected for an un-notarised ad-hoc build;\n'
    printf 'INFO          the user allows it once via System Settings > Privacy & Security\n'
  fi
}

# ---------------------------------------------------------------------------
# 8-9: the ZIP a user actually downloads
# ---------------------------------------------------------------------------
verify_zip() {
  local zip="$1"
  section "zip: $zip"

  if [ ! -f "$zip" ]; then
    fail "8. zip missing: $zip"
    return
  fi
  if unzip -t "$zip" >/dev/null 2>&1; then
    pass "8a. zip integrity (unzip -t)"
  else
    fail "8a. zip is corrupt"
    return
  fi
  # A user double-clicks Archive Utility, which is ditto. Mirror that.
  local tmp
  tmp="$(mktemp -d)"
  if ditto -x -k "$zip" "$tmp" >/dev/null 2>&1; then
    pass "8b. extracted with ditto (same tool Archive Utility uses)"
  else
    fail "8b. ditto could not extract the zip"
    rm -rf "$tmp"
    return
  fi
  local inner
  inner="$(find "$tmp" -maxdepth 2 -name '*.app' -print -quit)"
  if [ -z "$inner" ]; then
    fail "8c. no .app inside the zip"
    rm -rf "$tmp"
    return
  fi
  pass "8c. zip contains $(basename "$inner")"

  # 9. After a round trip the signature must still verify — that is what proves
  #    symlinks, permissions and nested code survived packaging.
  if codesign --verify --deep --strict --verbose=2 "$inner" >/dev/null 2>&1; then
    pass "9a. extracted bundle signature still verifies"
  else
    fail "9a. extracted bundle signature is broken (symlinks or permissions lost)"
  fi
  local exe_inner
  exe_inner="$(find "$inner/Contents/MacOS" -maxdepth 1 -type f -perm -u+x -print -quit)"
  if [ -n "$exe_inner" ]; then
    pass "9b. extracted executable keeps its +x bit"
  else
    fail "9b. extracted executable lost its +x bit"
  fi
  if [ -n "$(find "$inner" -type l | head -1)" ]; then
    pass "9c. extracted bundle keeps symlinks ($(find "$inner" -type l | wc -l | tr -d ' '))"
  else
    fail "9c. extracted bundle lost its symlinks"
  fi

  # Re-run the entitlement audit on the extracted copy: the ZIP must not be
  # able to smuggle in a different signature than the one we checked.
  if codesign -d --entitlements :- "$inner" 2>/dev/null | grep -q "keychain-access-groups"; then
    fail "9d. extracted bundle carries keychain-access-groups"
  else
    pass "9d. extracted bundle carries no keychain-access-groups"
  fi

  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
# 10: real launch
# ---------------------------------------------------------------------------
verify_launch() {
  local app="$1"
  section "launch: real LaunchServices start"

  # A sandboxed bundle must be started through LaunchServices. Exec-ing the
  # binary from a shell makes libsystem_secinit trap (SIGTRAP), which is a
  # property of the caller's context, not of the app.
  if ! launchctl print "gui/$(id -u)" >/dev/null 2>&1; then
    if [ "$ALLOW_GUI_SKIP" -eq 1 ]; then
      skip "10. no GUI session on this host — launch test not executed"
      return
    fi
    fail "10. no GUI session on this host — cannot prove the app starts"
    return
  fi

  local exec_name bundle_id container
  exec_name="$(plist "$app" CFBundleExecutable)"
  bundle_id="$(plist "$app" CFBundleIdentifier)"
  container="$HOME/Library/Containers/$bundle_id"
  local had_container=0
  [ -d "$container" ] && had_container=1

  local before_reports
  before_reports="$(ls -1 "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | wc -l | tr -d ' ')"

  local open_err
  if ! open_err="$(open -n "$app" 2>&1)"; then
    fail "10a. launchd refused to spawn the app: $open_err"
    return
  fi
  pass "10a. LaunchServices accepted the bundle"

  local pid="" waited=0
  while [ "$waited" -lt "$LAUNCH_TIMEOUT" ]; do
    pid="$(pgrep -f "$app/Contents/MacOS/$exec_name" | head -1)"
    [ -n "$pid" ] && break
    sleep 1
    waited=$((waited + 1))
  done

  if [ -z "$pid" ]; then
    fail "10b. process never appeared within ${LAUNCH_TIMEOUT}s"
    return
  fi

  # Stay alive: a crash right after start would still have produced a pid.
  sleep 4
  if kill -0 "$pid" >/dev/null 2>&1; then
    pass "10b. process $pid alive after $((waited + 4))s (did not crash on start)"
  else
    fail "10b. process died within $((waited + 4))s of starting"
    _dump_crash_hint "$exec_name"
    return
  fi

  # The dashboard reads SQLite on its first build, so a database on disk is
  # evidence the app got past main() and rendered a screen — not just that a
  # process exists.
  local db="$container/Data/Documents/materialword.sqlite"
  if [ -f "$db" ]; then
    pass "10c. app opened its database (first screen ran): ${db#"$HOME"/}"
  elif [ "$had_container" -eq 1 ]; then
    skip "10c. pre-existing container without a database — not asserted"
  else
    fail "10c. no database was created — the app never reached its first screen"
  fi

  local after_reports
  after_reports="$(ls -1 "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$after_reports" -eq "$before_reports" ]; then
    pass "10d. no new crash report written"
  else
    fail "10d. a new crash report appeared during launch"
    _dump_crash_hint "$exec_name"
  fi

  # Leave no running instance behind.
  pkill -f "$app/Contents/MacOS/$exec_name" 2>/dev/null
  sleep 1
  pass "10e. cleaned up the test instance"
}

_dump_crash_hint() {
  local name="$1"
  local newest
  newest="$(ls -t "$HOME"/Library/Logs/DiagnosticReports/"$name"*.ips 2>/dev/null | head -1)"
  if [ -n "$newest" ]; then
    printf 'INFO  newest crash report: %s\n' "$newest"
    python3 - "$newest" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
head, body = open(path).read().split("\n", 1)
b = json.loads(body)
print("INFO  exception:", b.get("exception", {}).get("type"), b.get("exception", {}).get("signal"))
for t in b.get("threads", []):
    if t.get("triggered"):
        imgs = b.get("usedImages", [])
        for f in t.get("frames", [])[:6]:
            i = f.get("imageIndex", -1)
            nm = imgs[i].get("name") if 0 <= i < len(imgs) else "?"
            print("INFO   ", nm, f.get("symbol", ""))
PY
  fi
}

# ---------------------------------------------------------------------------
main() {
  printf 'MaterialWord macOS bundle verification\n'
  printf 'host: macOS %s (%s)\n' "$(sw_vers -productVersion)" "$(uname -m)"

  if [ -n "$APP" ]; then
    verify_bundle "$APP" "app"
    if [ "$DO_LAUNCH" -eq 1 ]; then
      verify_launch "$APP"
    else
      skip "10. launch test not requested (--launch)"
    fi
  fi

  if [ -n "$ZIP" ]; then
    verify_zip "$ZIP"
  fi

  printf '\n----------------------------------------\n'
  printf 'summary: %d passed, %d failed, %d skipped\n' \
    "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    printf 'RESULT: FAIL\n'
    for f in "${FAILURES[@]}"; do printf '  - %s\n' "$f"; done
  else
    printf 'RESULT: PASS\n'
  fi

  if [ -n "$REPORT" ]; then
    {
      printf 'verify_passed=%d\n' "$PASS_COUNT"
      printf 'verify_failed=%d\n' "$FAIL_COUNT"
      printf 'verify_skipped=%d\n' "$SKIP_COUNT"
      printf 'verify_result=%s\n' "$([ "$FAIL_COUNT" -gt 0 ] && echo FAIL || echo PASS)"
    } >>"$REPORT"
  fi

  [ "$FAIL_COUNT" -gt 0 ] && exit 1
  exit 0
}

main
