# Yao Agents on Railway

[Yao](https://github.com/YaoApp/yao) — a self-hosted hub for AI agents: workspaces, a task board,
a dashboard, an Open API with SSE and WebSocket, built-in MCP tools, and desktop and Android
clients that connect to the server you run. This template runs the upstream image on Railway with
the one change a public URL demands: the root account gets a password that is yours.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/yao-agents)

## Service

| Service | Runs | Public | Role |
|---|---|---|---|
| `yao` | `yaoapp/yao:1.0.0-rc22` (upstream multi-arch image) + socat relay | **yes** | Engine, dashboard, Open API. App and SQLite database on `/data`. |

One service. The engine speaks plain HTTP; `socat` in front gives it a dual-stack listener (see
below).

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `YAO_ROOT_PASSWORD` | generated | Password of the root account `root@yaoagents.com`. Applied on **every** boot — change it here, not in the UI. |
| `DEFAULT_LLM` | *(app default: `moonshot.kimi-k2_5-code`)* | Which connector agents use by default, e.g. `deepseek.deepseek-chat`, `openai.gpt-4o`, `anthropic.claude-sonnet-4_5`. Written into the app's `.env`. |
| `DEEPSEEK_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `MOONSHOT_API_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_API_KEY`, `GROQ_API_KEY`, `MISTRAL_API_KEY`, `XAI_API_KEY`, … | *(empty)* | Provider credentials the bundled connectors read from the environment. Add the ones you use. |
| `YAO_JWT_SECRET` | *(empty)* | Optional. Signing secret for the legacy JWT helper; the Open API uses a per-install RSA key generated on first boot. |
| `YAO_ROOT` / `YAO_ENGINE_PORT` / `PORT` | `/data/yao` / `5099` / `8080` | Baked. App directory on the volume, engine port on loopback, public relay port. |

Nothing is required to deploy. Read `YAO_ROOT_PASSWORD` from the service's variables and sign in.

## First run

1. Open `https://<your-domain>/dashboard/auth/entry`.
2. Sign in as **`root@yaoagents.com`** with `YAO_ROOT_PASSWORD` from the service's variables.
3. Add a provider key (or set `DEFAULT_LLM` and its key) on the service and redeploy, then create a
   workspace and start a conversation — it becomes a task on the board.

Desktop and Android clients connect to the same URL. The Open API is under `/v1`.

## How it fits together

- **The root password is a constant upstream.** The bundled app's setup script creates
  `root@yaoagents.com` with the same password on every installation and prints it to the log. The
  entrypoint runs `yao init` on first boot, then re-hashes that account's password from
  `YAO_ROOT_PASSWORD` through the model layer (bcrypt) — verified against the stored hash: the
  upstream default is rejected, yours is accepted. It re-applies on every boot, so the Railway
  variable is the source of truth and a redeploy restores it. The entrypoint refuses to start with
  an empty or short value. Upstream hashes at bcrypt cost 4 (the library minimum), so keep the
  generated 24-character secret rather than replacing it with something memorable — the secret's
  entropy, not the hash, is what protects a leaked database file.
- **The app's `.env` beats your variables.** Yao loads `<app>/.env` with `godotenv.Overload`, so any
  key in that file overrides the process environment. First boot writes `YAO_HOST`, `YAO_PORT`,
  `YAO_ENV` there; the entrypoint rewrites them to `127.0.0.1`, `5099`, `production` on every boot
  (and `DEFAULT_LLM` when you set it). Provider keys are not in the file, so they pass straight
  through.
- **Dual-stack via socat.** Yao binds a single IPv4 address — `YAO_HOST` of `::`, `[::]` or empty
  logs `Listening` and then exits with `Host not found` — and `0.0.0.0` is invisible on Railway's
  IPv6-only private network. The engine binds `127.0.0.1:5099`; socat listens on `:8080` for both
  families and relays TCP, headers untouched.
- **The app directory is a subdirectory of the mount.** A Railway volume root holds `lost+found`,
  and `yao init` refuses a non-empty directory; `YAO_ROOT=/data/yao` sits beside it. It is not
  `/data/app` because that is the base image's `VOLUME` path, which a local `docker run` would
  shadow with an anonymous volume.
- **Runs as `yao`**, the base image's user; the entrypoint is root only long enough to create and
  own the app directory, then `su-exec`.
- **Agents can execute commands in this container.** `YAO_HOST_EXEC` is on by default with
  upstream's allow-lists; set `YAO_HOST_EXEC=false` on the service to turn it off.

## What persists

Everything: the installed application, its SQLite database (`/data/yao/db/yao.db`), uploads,
logs, the generated signing key and the session store all live under `/data/yao`.

## Not included

- **Stable releases.** Upstream tags `1.0.0-rcN` several times a week; the pin moves with them.
- **A model key.** Agents need a provider credential; none is bundled.
- **MySQL/Postgres.** SQLite is the upstream default and fine for one hub; `YAO_DB_DRIVER` and
  `YAO_DB_PRIMARY` in the app's `.env` switch it if you outgrow that.
- **Documentation links.** Upstream's `yaoagents.com/docs` returned 404 at the time of publishing;
  the source and `yao --help` were the references.

## Licence — read this one

Yao is licensed under a **modified Apache-2.0** ([LICENSE](https://github.com/YaoApp/yao/blob/main/LICENSE)).
The additional conditions: the Yao / Yao Agents branding and copyright must not be removed or
modified, the certificate-verification logic must be preserved, and **organisations with 50 or more
employees or more than USD 1,000,000 annual revenue must obtain a commercial licence** from
Infinite Wisdom Software. This template changes neither branding nor verification; whether your
organisation needs a commercial licence is yours to check. The glue in this repository is MIT.

## Upgrading

Bump `YAO_VERSION` in the `Dockerfile` and push. The engine migrates the database on start; back up
the volume first.

## Files

```
Dockerfile       FROM yaoapp/yao:<pin> + su-exec, socat, tini
entrypoint.sh    fail-closed password check, volume prep, first-boot init, .env patch, root rotation, relay, su-exec → yao start
railway.json     health check /, restart policy
```
