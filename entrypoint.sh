#!/bin/sh
set -eu

APP="${YAO_ROOT}"
ROOT_EMAIL="root@yaoagents.com"

# The installed app creates its root user with a password that is a constant in its own
# setup script, the same for every installation. On a public URL that is an open admin
# until someone changes it, so a deployment-specific password is required and applied
# on every boot; the Railway variable is the source of truth.
if [ -z "${YAO_ROOT_PASSWORD:-}" ]; then
    echo "FATAL: YAO_ROOT_PASSWORD is empty. Set it on this service (the template generates one)." >&2
    exit 1
fi
if [ "${#YAO_ROOT_PASSWORD}" -lt 12 ]; then
    echo "FATAL: YAO_ROOT_PASSWORD is ${#YAO_ROOT_PASSWORD} characters; use at least 12." >&2
    exit 1
fi

# Railway mounts the volume root-owned with a lost+found directory; the app lives in a
# subdirectory owned by the unprivileged user.
mkdir -p "${APP}"
chown -R yao:yao "${APP}"

# First boot: `yao init` installs the bundled application, migrates the database and runs
# the setup hook (roles, menus, root user), then exits. It refuses a non-empty directory.
if [ ! -f "${APP}/app.yao" ]; then
    echo "yao: first boot, installing the application into ${APP}"
    su-exec yao yao init -a "${APP}" 2>&1 | grep -vE '^\s+✓ |Root User Credentials|Email:|Password:|^=+$|^-+$' || true
    [ -f "${APP}/app.yao" ] || { echo "FATAL: yao init did not produce app.yao" >&2; exit 1; }
fi

# The app's .env is loaded with godotenv.Overload, so it beats the process environment for
# every key it contains. Set the deployment-shaped values in the file itself: production
# mode, the engine on loopback (socat fronts it), and its port.
setenv() { # key value
    if grep -qE "^$1=" "${APP}/.env"; then
        sed -i "s|^$1=.*|$1=\"$2\"|" "${APP}/.env"
    else
        printf '%s="%s"\n' "$1" "$2" >> "${APP}/.env"
    fi
}
setenv YAO_ENV production
setenv YAO_HOST 127.0.0.1
setenv YAO_PORT "${YAO_ENGINE_PORT}"
[ -n "${DEFAULT_LLM:-}" ] && setenv DEFAULT_LLM "${DEFAULT_LLM}"
chown yao:yao "${APP}/.env"

# Rotate the root password from the variable. The model layer bcrypt-hashes password_hash
# on save, and the login handler compares against that hash.
cd "${APP}"
su-exec yao yao run -a "${APP}" models.__yao.user.UpdateWhere \
    "::{\"wheres\":[{\"column\":\"email\",\"value\":\"${ROOT_EMAIL}\"}]}" \
    "::{\"password_hash\":\"${YAO_ROOT_PASSWORD}\"}" >/dev/null 2>&1 \
    && echo "yao: root password applied from YAO_ROOT_PASSWORD (login: ${ROOT_EMAIL})" \
    || { echo "FATAL: could not set the root password" >&2; exit 1; }

echo "yao: engine on 127.0.0.1:${YAO_ENGINE_PORT}, dual-stack relay on :${PORT}, app in ${APP}"
echo "yao: dashboard at https://${RAILWAY_PUBLIC_DOMAIN:-<your-domain>}/dashboard/auth/entry"

# Yao binds one IPv4 address; socat exposes it dual-stack so both the public edge and the
# private network reach it. TCP relay: headers arrive untouched.
su-exec yao socat "TCP6-LISTEN:${PORT},ipv6only=0,fork,reuseaddr" "TCP4:127.0.0.1:${YAO_ENGINE_PORT}" &

exec su-exec yao yao start -a "${APP}" "$@"
