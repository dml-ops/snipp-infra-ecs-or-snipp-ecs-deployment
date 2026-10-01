# Snipp — URL Shortener

A small three-tier app: React (Vite) frontend served by Caddy, a Node/Express
REST API, and Postgres. Built to drop straight into a Docker Compose +
Caddy + RDS deployment (frontend never talks to the DB directly, the backend
is never exposed on its own host port).

## Stack

- **Frontend**: React + Vite, built to static files, served by Caddy
- **Backend**: Node.js + Express, creates its own `links` table on startup
- **Database**: PostgreSQL (local Postgres container for dev, RDS in production)
- **Reverse proxy**: Caddy — serves the frontend, proxies `/api/*` to the
  backend, routes short code paths (e.g. `/AbC12de`) to the backend's
  redirect handler, and provisions its own TLS certificate automatically
  once it can see your domain

## How it works

- `POST /api/shorten` — takes `{ "url": "..." }`, returns a short code and URL
- `GET /:code` — looks up the code, increments its click count, 302-redirects
  to the original URL
- `GET /api/links` — lists recent links with their click counts (powers the
  list on the homepage)
- `GET /api/health` — checks the process **and** the DB connection; wire this
  into your load balancer health check / CloudWatch alarm

## Environment variables

| Variable | Where | Purpose |
|---|---|---|
| `DATABASE_URL` | backend | Full Postgres connection string |
| `APP_BASE_URL` | backend | Public domain used to build short URLs (e.g. `https://yourdomain.com`). Leave blank locally. |
| `DOMAIN` | caddy | Your domain (e.g. `yourdomain.com`); Caddy uses this to request its Let's Encrypt certificate. Use `localhost` for local testing. |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | postgres (local dev only) | Local Postgres container credentials |

## Run it locally

```bash
cp .env.local.example .env.local
docker compose --env-file .env.local up -d --build
```

Then open `http://localhost` and try shortening a link. Caddy won't get a
real certificate for `localhost`, it just serves over plain HTTP locally,
which is fine for a sanity check. Check the API directly with:

```bash
curl http://localhost/api/health
```

Tear down:

```bash
docker compose down -v
```

## Deploying

This app follows the same shape as the Docker Compose + GitHub Actions
guide: two repos (app + infra), images pushed to ECR, GitHub Actions SSHes
in and runs `docker compose up -d`, RDS replaces the local Postgres
container, and the private subnet / security group chain stays
`internet -> web_sg -> db_sg`.

One thing to adjust for a real deployment: drop the `postgres` service and
its port mapping from the production `docker-compose.yml`, and point
`DATABASE_URL` at the RDS endpoint instead, exactly like the guide's `sed`
swap from `build:` to `image:` for CI/CD. TLS needs nothing extra, Caddy
requests and renews its own Let's Encrypt certificate the moment it can
resolve your domain and see ports 80/443 reachable.

## Project structure

```
url-shortener/
├── backend/
│   ├── index.js          # Express API
│   ├── package.json
│   ├── Dockerfile
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── App.jsx
│   │   ├── App.css
│   │   └── main.jsx
│   ├── public/
│   │   └── config.js     # empty by default, same-origin API calls
│   ├── Dockerfile         # build stage only, Caddy does the serving
│   ├── vite.config.js
│   └── package.json
├── caddy/
│   └── Caddyfile
├── docker-compose.yml
├── .env.local.example
└── README.md
```
