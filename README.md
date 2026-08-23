# 🎬 Moviedarr

> Search for movies, grab NZBs from nzbs.in, and queue them straight to NZBGet — all from a sleek cinematic web UI.

---

## Features

- **Instant movie search** via the nzbs.in API with extended metadata
- **Smart quality badges** — automatically parsed from NZB titles (4K, 1080p, BluRay, WEB-DL, HDR, HEVC, Dolby Atmos, and more)
- **10 GB size cap** — oversized releases are filtered out automatically
- **Popularity sorting** — results ranked by grab count; hot releases flagged with 🔥
- **One-click queue** — sends directly to NZBGet via JSON-RPC with your configured category
- **Cinematic dark UI** — animated star field, glassmorphism cards, toast notifications
- **Containerized** — runs in Podman with a single start script

---

## Quick Start

### 1. Configure

```bash
cp .env.example .env
# Fill in your credentials:
#   NZBS_API_KEY, NZBGET_PASSWORD, STORAGE_PATH
nano .env
```

### 2. Build & Run

```bash
chmod +x podman_start.sh podman_stop.sh
./podman_start.sh
```

Open **http://\<SERVER_IP\>:5000** in your browser.

### 3. Stop

```bash
./podman_stop.sh
```

---

## Configuration (`.env`)

| Variable | Default | Description |
|---|---|---|
| `PORT` | `5000` | Host port for the web UI |
| `NZBS_API_KEY` | *(required)* | Your nzbs.in API key |
| `NZBGET_URL` | `http://localhost:6789` | NZBGet server address |
| `NZBGET_USERNAME` | `nzbget` | NZBGet username |
| `NZBGET_PASSWORD` | *(required)* | NZBGet password |
| `NZB_CATEGORY` | `Evaluate` | Category assigned in NZBGet |
| `MAX_SIZE_GB` | `10` | Maximum NZB size to display |
| `STORAGE_PATH` | `/path/to/your/nas/media` | NAS media path (mounted as `/media` in container) |

> `.env` is never committed to git.

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Web UI |
| `GET` | `/api/search?q=<title>` | Search nzbs.in, returns filtered results |
| `POST` | `/api/queue` | Queue an NZB to NZBGet |
| `GET` | `/api/health` | Health check + active config |

### POST `/api/queue` body

```json
{
  "url": "https://nzbs.in/...",
  "title": "Movie Title (2024)",
  "category": "Evaluate"
}
```

---

## Workflow

```
Search movie title
       ↓
nzbs.in API returns NZB list
       ↓
Results filtered to ≤ 10 GB, sorted by grabs
       ↓
Click "Queue" → NZBGet receives NZB (category: Evaluate)
       ↓
Your cron job moves completed files to NAS
```

---

## Stack

- **Backend**: Python 3.11 · Flask 3 · Gunicorn
- **Frontend**: Vanilla HTML/CSS/JS — no frameworks, no CDN dependencies
- **Container**: Podman (rootless)
- **APIs**: nzbs.in (Newznab), NZBGet JSON-RPC

---

## Changelog

### v1.0.0
- Initial release
- Movie search with nzbs.in API
- Quality badge auto-detection (4K, 1080p, HDR, HEVC, Atmos, etc.)
- 10 GB size filter + popularity sort
- One-click NZBGet queue with category support
- Cinematic UI with animated star field and glassmorphism cards
- Toast notifications
- Security headers on all responses
- Podman start/stop scripts with disk-space checks and image cleanup
