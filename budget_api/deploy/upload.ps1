# =============================================================================
# Oracle Cloud 서버로 파일 업로드 PowerShell 스크립트
# =============================================================================
# 사용법: .\upload.ps1 -PrivateKey "C:\path\to\key.pem" -ServerIP "123.45.67.89"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$PrivateKey,

    [Parameter(Mandatory=$true)]
    [string]$ServerIP,

    [string]$User = "ubuntu",
    [string]$RemotePath = "/opt/budget-api"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "Budget API 파일 업로드"
Write-Host "=========================================="

# 현재 스크립트 위치
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BudgetApiDir = Split-Path -Parent $ScriptDir

Write-Host "소스 디렉토리: $BudgetApiDir"
Write-Host "대상 서버: $User@$ServerIP:$RemotePath"

# 업로드할 파일 목록
$Files = @(
    "main.py",
    "database.py",
    "requirements.txt",
    ".env.example"
)

# 서버에 디렉토리 생성
Write-Host "`n[1/3] 원격 디렉토리 생성..."
ssh -i $PrivateKey "$User@$ServerIP" "sudo mkdir -p $RemotePath && sudo chown $User`:$User $RemotePath"

# 파일 업로드
Write-Host "`n[2/3] 파일 업로드..."
foreach ($File in $Files) {
    $LocalPath = Join-Path $BudgetApiDir $File
    if (Test-Path $LocalPath) {
        Write-Host "  업로드: $File"
        scp -i $PrivateKey $LocalPath "$User@$ServerIP`:$RemotePath/"
    } else {
        Write-Host "  건너뜀 (파일 없음): $File" -ForegroundColor Yellow
    }
}

# deploy 폴더 업로드
Write-Host "`n[3/3] deploy 폴더 업로드..."
scp -i $PrivateKey -r $ScriptDir "$User@$ServerIP`:$RemotePath/"

Write-Host ""
Write-Host "=========================================="
Write-Host "업로드 완료!" -ForegroundColor Green
Write-Host "=========================================="
Write-Host ""
Write-Host "다음 단계:"
Write-Host "1. 서버 접속: ssh -i $PrivateKey $User@$ServerIP"
Write-Host "2. 설치 실행: cd $RemotePath/deploy && chmod +x setup.sh && ./setup.sh"
Write-Host ""
