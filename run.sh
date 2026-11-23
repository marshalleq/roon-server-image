#!/bin/bash
# Entrypoint: checks the environment, downloads Roon Server on first run, then runs it as PUID:PGID.
# Every problem stops the container with a message that says what to fix. Nothing is defaulted.
set -euo pipefail

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "The container must start as root so it can switch to PUID:PGID. Remove any --user option."

[[ "${PUID:-}" =~ ^[0-9]+$ ]] || fail "PUID must be set to a numeric user id, for example -e PUID=568."
[[ "${PGID:-}" =~ ^[0-9]+$ ]] || fail "PGID must be set to a numeric group id, for example -e PGID=568."
[ "$PUID" -ne 0 ] || fail "PUID=0 would run Roon as root. Choose a non-root user id."
[ "$PGID" -ne 0 ] || fail "PGID=0 would run Roon as root. Choose a non-root group id."

[ -n "${ROON_DATAROOT:-}" ] || fail "ROON_DATAROOT is not set. The image sets it to /data."
[ -n "${ROON_ID_DIR:-}" ] || fail "ROON_ID_DIR is not set. The image sets it to /data."

as_user() {
    setpriv --reuid="$PUID" --regid="$PGID" --clear-groups "$@"
}

for dir in /app /data; do
    if ! as_user test -d "$dir" || ! as_user test -w "$dir"; then
        fail "$dir is missing or not writable by $PUID:$PGID. Mount a folder there and give it to that user, for example: chown -R $PUID:$PGID <folder on the host>"
    fi
done

# Roon breaks in odd ways on updates if /app and /data are the same folder, so check for that.
as_user rm -f /data/check-for-shared-with-data
as_user touch /app/check-for-shared-with-data
if [ -f /data/check-for-shared-with-data ]; then
    as_user rm -f /app/check-for-shared-with-data /data/check-for-shared-with-data
    fail "/app and /data are the same folder. Mount two different folders."
fi
as_user rm -f /app/check-for-shared-with-data

if [ ! -d /app/RoonServer ]; then
    [ -n "${ROON_SERVER_URL:-}" ] || fail "/app/RoonServer does not exist and ROON_SERVER_URL is not set."
    [ -n "${ROON_SERVER_PKG:-}" ] || fail "/app/RoonServer does not exist and ROON_SERVER_PKG is not set."
    echo "Downloading Roon Server from $ROON_SERVER_URL"
    # The single quotes are deliberate: the variables are expanded by the inner shell, as PUID:PGID.
    # shellcheck disable=SC2016
    as_user bash -c 'cd /app && curl --fail --location --silent --show-error --output "$ROON_SERVER_PKG" "$ROON_SERVER_URL" && tar xjf "$ROON_SERVER_PKG" && rm -f "$ROON_SERVER_PKG"' \
        || fail "Downloading or unpacking Roon Server failed. Check the container can reach $ROON_SERVER_URL."
fi

[ -x /app/RoonServer/start.sh ] || fail "/app/RoonServer/start.sh is missing or not executable. Delete /app/RoonServer so it is downloaded again."

# Roon's .NET runtime needs a writable home folder, and $PUID has no entry in /etc/passwd.
export HOME=/data
exec setpriv --reuid="$PUID" --regid="$PGID" --clear-groups /app/RoonServer/start.sh
