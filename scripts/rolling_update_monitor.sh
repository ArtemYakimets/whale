#!/bin/bash

LOGFILE=/tmp/rolling_update_monitor.log
> $LOGFILE

echo "[MONITOR] Starting background monitoring..."

# Запускаем мониторинг в фоне (240 секунд)
(
    for i in {1..240}; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 2>/dev/null || echo "ERR")
        TIMESTAMP=$(date +%H:%M:%S)
        if [ "$STATUS" = "200" ]; then
            echo "[$TIMESTAMP] CTFd: $STATUS OK"
        else
            echo "[$TIMESTAMP] CTFd: $STATUS FAIL"
        fi
        sleep 1
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
echo "=== Updating all services ==="

# Функция ожидания готовности сервиса
wait_for_service() {
    local svc=$1
    local max_wait=${2:-30}
    echo "  Waiting for $svc to be ready..."
    for i in $(seq 1 $max_wait); do
        REPLICAS=$(docker service ls --filter "name=$svc" --format "{{.Replicas}}" 2>/dev/null)
        if [ "$REPLICAS" = "1/1" ] || [ "$REPLICAS" = "2/2" ]; then
            echo "  $svc is ready! ($REPLICAS)"
            return 0
        fi
        sleep 1
    done
    echo "  Warning: $svc may not be fully ready ($REPLICAS)"
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

# 2. Затем приложения 
echo ""
echo "--- Phase 2: Application services ---"
echo "Updating ctfd_ctfd..."
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
