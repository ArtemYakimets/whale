#!/bin/bash
set -e

echo "=========================================="
echo "  CTFd Rolling Update with Monitoring"
echo "=========================================="
echo ""

# Проверка до обновления
echo "[CHECK] Service status BEFORE update:"
vagrant ssh manager -c "docker service ls --filter 'name=ctfd_' --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}'"

echo ""
echo "[UPDATE] Starting rolling update with live monitoring..."
echo ""

# Запускаем скрипт с мониторингом на VM
vagrant ssh manager -c "bash /vagrant/scripts/rolling_update_monitor.sh"

echo ""
echo "=========================================="
echo "  Final Healthcheck Status"
echo "=========================================="
vagrant ssh manager -c "docker service ps ctfd_ctfd ctfd_nginx ctfd_db ctfd_cache ctfd_frps ctfd_frpc --filter 'desired-state=running' --format 'table {{.Name}}\t{{.CurrentState}}'"

echo ""
echo "=========================================="
echo "  Rolling Update Complete!"
echo "=========================================="
