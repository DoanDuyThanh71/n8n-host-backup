# =============================================================
# setup-n8n-backup.ps1 - Cài đặt n8n phiên bản VPS Local
# Thư mục cài đặt cố định: C:\n8n-local
# =============================================================

$ErrorActionPreference = "Stop"
$INSTALL_DIR = "C:\n8n-local"

function Write-Step($msg) { Write-Host "`n[STEP] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-WARN($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Write-ERR($msg)  { Write-Host " [ERR] $msg" -ForegroundColor Red; exit 1 }

# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║       Cài Đặt n8n Local (Đồng Bộ Cấu Hình VPS)    ║" -ForegroundColor Magenta
Write-Host "║         Thư mục cài đặt: C:\n8n-local            ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# 1. Kiểm tra Docker
Write-Step "1/5 - Kiểm tra Docker Desktop..."
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-WARN "Docker chưa được cài. Đang mở trang tải Docker Desktop..."
    Start-Process "https://www.docker.com/products/docker-desktop/"
    Write-ERR "Hãy cài Docker Desktop xong rồi chạy lại script này!"
}

# Kiểm tra Docker daemon
$dockerRunning = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-WARN "Docker Desktop chưa khởi động. Đang mở Docker Desktop..."
    Start-Process "C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe" -ErrorAction SilentlyContinue
    Write-Host "  Đang chờ Docker khởi động (tối đa 60 giây)..." -ForegroundColor Yellow
    $waited = 0
    do {
        Start-Sleep -Seconds 5
        $waited += 5
        Write-Host "  ... $waited giây" -ForegroundColor Gray
        $dockerRunning = docker info 2>&1
    } while ($LASTEXITCODE -ne 0 -and $waited -lt 60)

    if ($LASTEXITCODE -ne 0) {
        Write-ERR "Docker vẫn chưa chạy. Hãy mở Docker Desktop thủ công và chạy lại script."
    }
}
Write-OK "Docker đang chạy!"

# 2. Tạo thư mục cài đặt
Write-Step "2/5 - Tạo thư mục cài đặt tại $INSTALL_DIR"
if (-not (Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR | Out-Null
}
Write-OK "Thư mục cài đặt sẵn sàng."

# 3. Tạo Dockerfile (Tích hợp FFmpeg)
Write-Step "3/5 - Ghi file Dockerfile..."
$dockerfileContent = @"
# Multi-stage build to get static ffmpeg
FROM mwader/static-ffmpeg:6.0 AS ffmpeg

FROM n8nio/n8n:2.14.2

USER root

# Copy ffmpeg/ffprobe binaries
COPY --from=ffmpeg /ffmpeg /usr/local/bin/
COPY --from=ffmpeg /ffprobe /usr/local/bin/

# Ensure permissions
RUN chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

USER node
"@

$dockerfileContent | Out-File -FilePath (Join-Path $INSTALL_DIR "Dockerfile") -Encoding utf8 -Force
Write-OK "Tạo Dockerfile thành công."

# 4. Ghi file docker-compose.yml
Write-Step "4/5 - Ghi file docker-compose.yml (Đã cấu hình localhost)..."
$composeContent = @"
services:
  n8n:
    build: .
    restart: always
    ports:
      - "5678:5678"
    dns:
      - 8.8.8.8
      - 1.1.1.1
    environment:
      - NODE_OPTIONS=--max-old-space-size=4096
      - NODES_EXCLUDE="[]"
      - N8N_HOST=localhost
      - N8N_SECURE_COOKIE=false
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=24
      - EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
      - EXECUTIONS_DATA_SAVE_ON_ERROR=all
      - EXECUTIONS_DATA_SAVE_ON_PROGRESS=false
      - DB_SQLITE_VACUUM_ON_STARTUP=true
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_RUNNERS_ENABLED=false
      - N8N_PAYLOAD_SIZE_MAX=500
      - N8N_BLOCK_FS_WRITE_ACCESS=false
      - N8N_RESTRICT_FILE_ACCESS_TO=/home/node/.n8n;/tmp;/shared_videos;/home/node/n8n;/home/node/.n8n/binaryData
      - N8N_BINARY_DATA_TTL=60
      - EXECUTIONS_DATA_MAX_SIZE=500
      - N8N_BINARY_DATA_STORAGE_PATH=/home/node/.n8n/binaryData
      - NODE_FUNCTION_ALLOW_EXTERNAL=*
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_METRICS=false
    volumes:
      - ./n8n_data:/home/node/.n8n
      - ./shared_videos:/shared_videos
      - ./binaryData:/home/node/.n8n/binaryData
"@

$composeContent | Out-File -FilePath (Join-Path $INSTALL_DIR "docker-compose.yml") -Encoding utf8 -Force
Write-OK "Tạo docker-compose.yml thành công."

# 5. Khởi chạy Docker Compose
Write-Step "5/5 - Đang build image và khởi động n8n..."
Set-Location $INSTALL_DIR
docker compose up --build -d

if ($LASTEXITCODE -ne 0) {
    Write-ERR "Có lỗi khi chạy docker compose."
}
Write-OK "n8n đang khởi động..."

# Đợi và mở trình duyệt
$ready = $false
$tries = 0
do {
    Start-Sleep -Seconds 3
    $tries++
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5678" -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { $ready = $true }
    } catch {}
} while (-not $ready -and $tries -lt 40)

if ($ready) {
    Start-Process "http://localhost:5678"
    Write-OK "n8n đã sẵn sàng!"
} else {
    Write-WARN "n8n khởi động lâu hơn dự kiến. Tự mở: http://localhost:5678"
    Start-Process "http://localhost:5678"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              CÀI ĐẶT HOÀN TẤT!                   ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  🌐 Web UI  : http://localhost:5678             ║" -ForegroundColor Green
Write-Host "║  📂 Folder  : C:\n8n-local                       ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
