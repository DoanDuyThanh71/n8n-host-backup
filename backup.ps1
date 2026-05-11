Set-Location D:\PJ\n8n-host-backup\editVideo

docker run --rm `
  -v n8n-docker_n8n_data:/data `
  -v D:\PJ\n8n-host-backup\editVideo:/backup `
  alpine tar czf /backup/n8n-data.tar.gz /data

Write-Host "Backup volume xong!"

git add .
git commit -m "backup: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git push origin main

Write-Host "Push GitHub xong!"
