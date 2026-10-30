# Doory — open-source Canva alternative with real-time co-editing. Deploy on Railway with one click.

[Doory](https://github.com/shaongitbd/doory) is a self-hosted design editor (templates, PDF export, live collaboration). This template packages the official `doory-backend` and `doory-frontend` 0.2.0 images into one Railway service (`ghcr.io/onepush-dev/doory:0.2.0`): nginx serves the SPA and proxies to the Django API (gunicorn) and the realtime WebSocket server (uvicorn). They share one media volume, as in upstream docker-compose (Railway volumes can't be shared between services). Postgres 18 (Railway postgres-ssl:18) holds the data.

## Services
| Service | Image | Port | Volume |
|---|---|---|---|
| Doory | `ghcr.io/onepush-dev/doory:0.2.0` | 8080 (public) | `/app/media` |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:16` | 5432 (private) | `/var/lib/postgresql/data` |

## First sign-in
An admin account is created on first start from `DOORY_ADMIN_EMAIL` (default `admin@example.com`) and the generated `DOORY_ADMIN_PASSWORD` (see Variables). Emails print to the log until you set `EMAIL_URL`.

## Optional
Fonts and the element library download on first start (`DOORY_SYNC_FONTS`, `DOORY_SYNC_ELEMENTS`). Redis and the MCP server are not included (single realtime worker doesn't need Redis).
