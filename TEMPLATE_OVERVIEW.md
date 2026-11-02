# Deploy and Host Yao Agents on Railway

[Yao](https://github.com/YaoApp/yao) is a self-hosted hub for AI agents: isolated workspaces, a
task board that turns conversations into tracked work, a dashboard, an Open API with SSE and
WebSocket, built-in MCP tools, and desktop and Android clients that connect to the server you
run. This template deploys the upstream Yao image (1.0.0-rc22) on Railway, with one addition that
a public URL requires: the root account's password is yours, generated for this deployment.

## About Hosting Yao

Yao publishes a production container image and installs its own application on first start —
database migration, roles, menus and a root user included — so there is nothing to build. What it
does not do is choose a root password for you: the bundled setup script creates
`root@yaoagents.com` with the same constant password on every installation. This template's
entrypoint runs that first-boot install, then re-hashes the root password from a Railway-generated
secret before the server accepts a connection, and re-applies it on every boot. It also writes the
production mode and loopback bind into the application's own `.env` (which overrides the process
environment) and fronts the IPv4-only engine with a dual-stack relay, so both the public edge and
Railway's private network reach it.

## Common Use Cases

- One always-on hub for your agents, reachable from the desktop app, the Android app and any
  browser, with workspaces that stay separate and a board that tracks what agents are doing.
- Expose expert and task agents to your own applications through the Open API (SSE and
  WebSocket) without running the engine on a laptop.
- A team's shared agent workspace with roles, teams and invitation codes, on a single small
  service with SQLite.

## Dependencies for Yao Hosting

- A volume for the application and its database, which the template creates.
- A model provider key — DeepSeek, OpenAI, Anthropic, Moonshot, OpenRouter, Google, Groq,
  Mistral, xAI and others are wired as connectors that read `PROVIDER_API_KEY` (for example `XAI_API_KEY`) from the
  environment. Add yours to the service; none is required to deploy.

### Deployment Dependencies

- [Yao](https://github.com/YaoApp/yao) — upstream project, image `yaoapp/yao` on Docker Hub.
  Licensed under a **modified Apache-2.0**: branding and certificate verification must be kept
  intact, and organisations with 50+ employees or over USD 1M revenue need a commercial licence
  from upstream. This template changes neither branding nor verification.
- [Template repository](https://github.com/RockinPaul/yao_railway_template) (MIT).

### Implementation Details

One service, `yao`: `yaoapp/yao:1.0.0-rc22` with `su-exec`, `socat` and `tini` added. Health check
`/` (200 unauthenticated). Volume at `/data`; the application lives in `/data/yao` — a
subdirectory, because the mount root holds `lost+found` and Yao refuses to initialise a non-empty
directory. Runs as the image's `yao` user. The engine binds `127.0.0.1:5099`; socat listens on
the service port for IPv4 and IPv6 and relays to it.

**First run:** open `/dashboard/auth/entry`, sign in as `root@yaoagents.com` with
`YAO_ROOT_PASSWORD` from the service's variables, add a provider key, create a workspace. The
entrypoint refuses to start without a password of at least 12 characters.

Three things to know. `YAO_ROOT_PASSWORD` is applied on every boot, so change it in Railway, not
in the UI. Agents can execute commands inside the container by default (`YAO_HOST_EXEC`, with
upstream's allow-lists; set it to `false` to disable). And upstream ships `1.0.0-rc` tags several
times a week, so the pinned version moves often.

## Why Deploy Yao on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying Yao on Railway, you are one step closer to supporting a complete full-stack
application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
