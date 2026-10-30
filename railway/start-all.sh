#!/bin/bash
# Runs as root: fixes volume ownership, then starts the API and realtime as the unprivileged doory user.
set -euo pipefail
MEDIA="${MEDIA_ROOT:-/app/media}"; EXPORTS="${EXPORT_STORAGE_ROOT:-/app/exports}"
mkdir -p "$MEDIA" "$EXPORTS"
chown -R doory:doory "$MEDIA" "$EXPORTS" 2>/dev/null || true
chmod a+rX "$MEDIA"
run_as() { setpriv --reuid=10001 --regid=10001 --init-groups -- "$@"; }
cd /app

# API: the upstream entrypoint migrates, creates the cache table and collects static before gunicorn.
run_as /app/docker-entrypoint.sh gunicorn doory.wsgi:application \
  --bind 127.0.0.1:8000 --worker-class gthread --threads 4 --workers "${WEB_CONCURRENCY:-2}" \
  --timeout 120 --graceful-timeout 30 --worker-tmp-dir /dev/shm --access-logfile - &
API=$!

# Wait for the API (migrations done) before realtime and the admin bootstrap.
for i in $(seq 1 180); do
  if HEALTH_PORT=8000 python /app/healthcheck.py; then break; fi
  kill -0 $API 2>/dev/null || { echo "API exited during start-up" >&2; exit 1; }
  sleep 2
done

# Optional admin account from DOORY_ADMIN_EMAIL / DOORY_ADMIN_PASSWORD (created once, never overwritten).
if [ -n "${DOORY_ADMIN_EMAIL:-}" ] && [ -n "${DOORY_ADMIN_PASSWORD:-}" ]; then
  run_as python manage.py shell -c "
import os
from django.contrib.auth import get_user_model
U = get_user_model(); e = os.environ['DOORY_ADMIN_EMAIL']
if not U.objects.filter(email__iexact=e).exists():
    U.objects.create_superuser(email=e, password=os.environ['DOORY_ADMIN_PASSWORD'])
    print('Doory admin account created:', e)
else:
    print('Doory admin account exists:', e)
" || echo "Admin bootstrap failed; create one with: python manage.py createsuperuser" >&2
fi

run_as /app/docker-entrypoint.sh uvicorn doory.asgi:application --host 127.0.0.1 --port 8001 \
  --workers 1 --ws auto --ws-max-size 2097152 --lifespan off --no-server-header --timeout-graceful-shutdown 20 &
RT=$!

PORT="${PORT:-8080}"
sed -i -E "s/listen (\[::\]:)?[0-9]+ default_server;/listen \1${PORT} default_server;/" /etc/nginx/conf.d/doory.conf
nginx -g 'daemon off;' &
NG=$!
echo "Doory up: nginx :$PORT -> api :8000, realtime :8001"
wait -n $API $RT $NG
echo "A Doory process exited; stopping the container so Railway restarts it" >&2
exit 1
