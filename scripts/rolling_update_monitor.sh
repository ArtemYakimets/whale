#!/bin/bash
# Скрипт rolling update с мониторингом (запускается на manager VM)

LOGFILE=/tmp/rolling_update_monitor.log
> $LOGFILE

echo "[MONITOR] Starting background monitoring..."

# Запускаем мониторинг в фоне (120 секунд)
(
    for i in {1..240}; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 2>/dev/null || echo "ERR")
        TIMESTAMP=$(date +%H:%M:%S)
        if [ "$STATUS" = "200" ]; then
            echo "[$TIMESTAMP] CTFd: $STATUS OK"
        else
            echo "[$TIMESTAMP] CTFd: $STATUS FAIL"
        fi
        sleep 0.5
    done
) > $LOGFILE 2>&1 &
MONITOR_PID=$!

echo "[MONITOR] Started (PID: $MONITOR_PID)"
echo ""

sleep 1

# Выполняем rolling update
echo "=== Syncing configuration from /vagrant ==="
cp /vagrant/docker-compose.yml ~/ctfd-deployment/
cp -r /vagrant/conf ~/ctfd-deployment/

cd ~/ctfd-deployment
echo "=== Deploying stack configuration ==="
docker stack deploy -c docker-compose.yml ctfd

echo ""
echo "=== Force updating all services (in correct order) ==="

# Функция ожидания готовности сервиса
wait_for_service() {
    local svc=$1
    local max_wait=${2:-30}
    echo "  Waiting for $svc to be ready..."
    for i in $(seq 1 $max_wait); do
        REPLICAS=$(docker service ls --filter "name=$svc" --format "{{.Replicas}}" 2>/dev/null)
        if [ "$REPLICAS" = "1/1" ]; then
            echo "  $svc is ready!"
            return 0
        fi
        sleep 1
    done
    echo "  Warning: $svc may not be fully ready"
    return 1
}

# 1. Сначала FRP (независимые)
echo ""
echo "--- Phase 1: FRP services ---"
for svc in ctfd_frps ctfd_frpc; do
    echo "Updating $svc..."
    docker service update --force $svc
    wait_for_service $svc 20
done

# 2. Потом инфраструктура (cache, db) - ВАЖНО дождаться!
echo ""
echo "--- Phase 2: Infrastructure services ---"
echo "Updating ctfd_cache..."
docker service update --force ctfd_cache
wait_for_service ctfd_cache 30

echo "Updating ctfd_db..."
docker service update --force ctfd_db
wait_for_service ctfd_db 60

# 3. В конце приложения (ctfd зависит от cache и db)
echo ""
echo "--- Phase 3: Application services ---"
echo "Updating ctfd_ctfd (this takes longer)..."
docker service update --force ctfd_ctfd
wait_for_service ctfd_ctfd 120

echo "Updating ctfd_nginx..."
docker service update --force ctfd_nginx
wait_for_service ctfd_nginx 30

echo ""
echo "=== All services updated ==="
sleep 5

echo ""
echo "=== Service status ==="
docker service ls --filter "name=ctfd_"

# Останавливаем мониторинг
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo "  MONITORING LOG (during update):"
echo "=========================================="
cat $LOGFILE
