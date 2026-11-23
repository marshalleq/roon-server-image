#!/usr/bin/env bash
# Tests the entrypoint (run.sh) against a built image, without downloading Roon.
# Usage: test-entrypoint.sh <image>
# Uses named Docker volumes (not host folders) so it behaves the same on a Mac and on a CI runner.
# sed is used to indent captured output; the suggested ${var//} form cannot do a per-line prefix.
# shellcheck disable=SC2001
set -euo pipefail

IMAGE="${1:?usage: test-entrypoint.sh <image>}"
SUFFIX="$$-$RANDOM"
UID_TEST=12345
GID_TEST=23456
failures=0
volumes=()

cleanup() {
    if [ "${#volumes[@]}" -gt 0 ]; then
        docker volume rm -f "${volumes[@]}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

vol() {
    local name="rsi-test-$1-$SUFFIX"
    docker volume create "$name" >/dev/null
    volumes+=("$name")
    echo "$name"
}

# Give a volume to a user, and optionally put a fake RoonServer in it.
prepare() {
    local volume="$1" owner="$2" fake="${3:-no}"
    docker run --rm --entrypoint bash -v "$volume:/v" "$IMAGE" -c "
        set -e
        if [ '$fake' = yes ]; then
            mkdir -p /v/RoonServer
            cat > /v/RoonServer/start.sh <<'EOF'
#!/bin/sh
echo \"uid=\$(id -u) gid=\$(id -g) home=\$HOME\"
touch /app/created-by-roon /data/created-by-roon
EOF
            chmod 755 /v/RoonServer/start.sh
        fi
        chown -R '$owner' /v
    "
}

expect_failure() {
    local description="$1" expected="$2"
    shift 2
    local output status=0
    output="$("$@" 2>&1)" || status=$?
    if [ "$status" -ne 1 ]; then
        echo "FAIL: $description: expected exit 1, got $status"
        echo "$output" | sed 's/^/      /'
        failures=$((failures + 1))
    elif ! grep -qF -- "$expected" <<<"$output"; then
        echo "FAIL: $description: message did not contain: $expected"
        echo "$output" | sed 's/^/      /'
        failures=$((failures + 1))
    else
        echo "ok:   $description"
    fi
}

app="$(vol app)"
data="$(vol data)"
prepare "$app" "$UID_TEST:$GID_TEST" yes
prepare "$data" "$UID_TEST:$GID_TEST"

run() {
    docker run --rm "$@" "$IMAGE"
}

expect_failure "PUID not set" "PUID must be set" \
    run -e PGID=$GID_TEST -v "$app:/app" -v "$data:/data"
expect_failure "PUID not a number" "PUID must be set to a numeric" \
    run -e PUID=abc -e PGID=$GID_TEST -v "$app:/app" -v "$data:/data"
expect_failure "PGID not set" "PGID must be set" \
    run -e PUID=$UID_TEST -v "$app:/app" -v "$data:/data"
expect_failure "PUID 0 refused" "PUID=0 would run Roon as root" \
    run -e PUID=0 -e PGID=$GID_TEST -v "$app:/app" -v "$data:/data"
expect_failure "started with --user" "must start as root" \
    run --user 1000 -e PUID=$UID_TEST -e PGID=$GID_TEST -v "$app:/app" -v "$data:/data"
expect_failure "ROON_DATAROOT empty" "ROON_DATAROOT is not set" \
    run -e ROON_DATAROOT= -e PUID=$UID_TEST -e PGID=$GID_TEST -v "$app:/app" -v "$data:/data"
expect_failure "/data not mounted as a writable folder for the user" "/data is missing or not writable" \
    run -e PUID=$UID_TEST -e PGID=$GID_TEST -v "$app:/app"
wrong_owner="$(vol wrongowner)"
prepare "$wrong_owner" "0:0"
expect_failure "/data owned by someone else" "chown -R $UID_TEST:$GID_TEST" \
    run -e PUID=$UID_TEST -e PGID=$GID_TEST -v "$app:/app" -v "$wrong_owner:/data"
expect_failure "/app and /data are the same folder" "same folder" \
    run -e PUID=$UID_TEST -e PGID=$GID_TEST -v "$app:/app" -v "$app:/data"

# Download failure: no RoonServer present and an unreachable address.
empty_app="$(vol emptyapp)"
prepare "$empty_app" "$UID_TEST:$GID_TEST"
expect_failure "download from an unreachable address fails loudly" "Downloading or unpacking Roon Server failed" \
    run -e PUID=$UID_TEST -e PGID=$GID_TEST -e ROON_SERVER_URL=http://127.0.0.1:9/none.tar.bz2 -v "$empty_app:/app" -v "$data:/data"

# Success path: a fake RoonServer proves the user switch, the home folder and file ownership.
status=0
output="$(run -e PUID=$UID_TEST -e PGID=$GID_TEST -v "$app:/app" -v "$data:/data" 2>&1)" || status=$?
if [ "$status" -eq 0 ] && grep -qF "uid=$UID_TEST gid=$GID_TEST home=/data" <<<"$output"; then
    echo "ok:   runs as PUID:PGID with HOME=/data"
else
    echo "FAIL: success path (exit $status): $output"
    failures=$((failures + 1))
fi
owner="$(docker run --rm --entrypoint stat -v "$app:/app" "$IMAGE" -c '%u:%g' /app/created-by-roon)"
if [ "$owner" = "$UID_TEST:$GID_TEST" ]; then
    echo "ok:   files Roon creates belong to PUID:PGID"
else
    echo "FAIL: created file owner is $owner, expected $UID_TEST:$GID_TEST"
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed" >&2
    exit 1
fi
echo "All entrypoint tests passed."
