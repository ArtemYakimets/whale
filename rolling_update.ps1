Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CTFd Rolling Update with Monitoring" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Проверка до обновления
Write-Host "[CHECK] Service status BEFORE update:" -ForegroundColor Yellow
vagrant ssh manager -c "docker service ls --filter 'name=ctfd_' --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}'"

Write-Host ""
Write-Host "[UPDATE] Starting rolling update with live monitoring..." -ForegroundColor Yellow
Write-Host ""

# Запускаем скрипт с мониторингом на VM
vagrant ssh manager -c "bash /vagrant/scripts/rolling_update_monitor.sh"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Final Healthcheck Status" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
vagrant ssh manager -c "docker service ps ctfd_ctfd ctfd_nginx ctfd_db ctfd_cache ctfd_frps ctfd_frpc --filter 'desired-state=running' --format 'table {{.Name}}\t{{.CurrentState}}'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rolling Update Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
