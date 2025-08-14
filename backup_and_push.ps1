# ===== 配置区 =====
$projectPath = "D:\Ccode\MiddleSwitchCpp"
$allowedExt  = @(".cpp", ".h", ".rc", ".ico", ".png", ".jpg", ".md", ".txt", ".bat", ".ps1")
$maxSizeMB   = 50
# ===== 配置结束 =====

# === 防呆锁 ===
if ((Get-Location).ProviderPath -ne $projectPath) {
    Write-Host "错误：当前目录不是 $projectPath" -ForegroundColor Red
    Write-Host "请先运行：cd `"$projectPath`"" -ForegroundColor Yellow
    exit
}

# === 自动维护 .gitignore ===
$gitignorePath = Join-Path $projectPath ".gitignore"
$ignoreRules = @"
# VS 缓存
.vs/

# 构建输出
x64/
Debug/
Release/

# 备份目录
backup*/

# 临时文件
*.tmp
*.log

# 系统文件
Thumbs.db
Desktop.ini
"@

if (-not (Test-Path $gitignorePath)) {
    $ignoreRules | Out-File -Encoding UTF8 $gitignorePath
    Write-Host "已创建新的 .gitignore" -ForegroundColor Green
}
else {
    $current = Get-Content $gitignorePath -Raw
    $updated = $false
    foreach ($line in $ignoreRules -split "`n") {
        if ($line.Trim() -ne "" -and $current -notmatch [Regex]::Escape($line.Trim())) {
            Add-Content -Encoding UTF8 $gitignorePath $line
            $updated = $true
        }
    }
    if ($updated) {
        Write-Host ".gitignore 已更新，添加缺失规则" -ForegroundColor Yellow
    }
    else {
        Write-Host ".gitignore 已符合预期规则" -ForegroundColor Cyan
    }
}

# === 创建备份目录 ===
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "backup_$timestamp"
Write-Host ">>> 创建本地备份: $backupDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $backupDir | Out-Null

Write-Host ">>> 开始复制源码与资源文件..." -ForegroundColor Cyan
Get-ChildItem -LiteralPath $projectPath -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object {
        -not $_.PSIsContainer -and
        $allowedExt -contains $_.Extension.ToLower() -and
        $_.Length -lt ($maxSizeMB * 1MB) -and
        $_.FullName -notmatch '\\(\.git|\.vs|obj|bin)($|\\)' -and
        $_.FullName -notmatch '\\backup[^\\]*($|\\)' -and
        -not ($_.Extension -eq ".ps1" -and $_.Name.ToLower().StartsWith("backup")) -and
        $_.FullName.Length -lt 260
    } |
    ForEach-Object {
        Write-Host "复制: $($_.FullName)" -ForegroundColor Gray
        try {
            $stream = [System.IO.File]::Open($_.FullName, 'Open', 'Read', 'ReadWrite')
            $stream.Close()
            $relative = $_.FullName.Substring($projectPath.Length).TrimStart('\')
            $target = Join-Path $backupDir $relative
            $targetDir = Split-Path $target
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item $_.FullName -Destination $target -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "跳过被占用或不可读文件: $($_.FullName)"
        }
    }

# === Git 同步（安全处理） ===
git add -u   # 暂存已跟踪的修改/删除
git stash push -m "Auto-stash before backup_and_push"  # 仅 stash 已跟踪变更
git pull --rebase origin main
git stash pop

# 提交说明
$commitMessage = Read-Host ">>> 请输入提交说明（默认：Auto backup $timestamp）"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Auto backup $timestamp"
}

# 白名单提交新文件（存在才 add）
foreach ($ext in $allowedExt) {
    $files = Get-ChildItem -LiteralPath $projectPath -Recurse -Force `
             -ErrorAction SilentlyContinue -Include "*$ext" -File |
             Where-Object { $_.FullName.Length -lt 260 }
    if ($files.Count -gt 0) {
        git add "*$ext"
    }
}

git commit -m "$commitMessage"
git push

Write-Host ">>> 备份与推送完成！" -ForegroundColor Green
