# ====== 配置区 ======
$projectPath = "D:\Ccode\MiddleSwitchCpp"
$allowedExt  = @(".cpp", ".h", ".rc", ".ico", ".png", ".jpg", ".md", ".txt", ".bat", ".ps1")
$maxSizeMB   = 50
# ====== 配置结束 ======

# === 安全锁 ===
if ((Get-Location).ProviderPath -ne $projectPath) {
    Write-Host "错误：当前目录不是 $projectPath" -ForegroundColor Red
    Write-Host "请先运行：cd `"$projectPath`"" -ForegroundColor Yellow
    exit
}

# 创建备份目录
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "backup_$timestamp"
Write-Host ">>> 创建本地备份: $backupDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $backupDir | Out-Null

Write-Host ">>> 开始复制源码与资源文件..." -ForegroundColor Cyan
Get-ChildItem -Path $projectPath -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object {
        -not $_.PSIsContainer -and
        $allowedExt -contains $_.Extension.ToLower() -and
        $_.Length -lt ($maxSizeMB * 1MB) -and

        # 排除目录
        $_.FullName -notmatch '\\(\.git|\.vs|obj|bin)($|\\)' -and
        $_.FullName -notmatch '\\backup[^\\]*($|\\)' -and

        # 排除以 backup 开头的 .ps1 文件
        -not ($_.Extension -eq ".ps1" -and $_.Name.ToLower().StartsWith("backup"))
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

# ===== Git 提交白名单方式 =====
# 确保 .gitignore 忽略无关目录
$gitignorePath = Join-Path $projectPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    @"
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
"@ | Out-File -Encoding UTF8 $gitignorePath
}

git pull --rebase origin main

$commitMessage = Read-Host ">>> 请输入提交说明（默认：Auto backup $timestamp）"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Auto backup $timestamp"
}

# 先暂存已跟踪文件的修改与删除
git add -u
# 再添加白名单类型的新文件
foreach ($ext in $allowedExt) {
    git add "*$ext"
}

git commit -m "$commitMessage"
git push

Write-Host ">>> 备份与推送完成！" -ForegroundColor Green
