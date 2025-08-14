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

        # 排除目录
        $_.FullName -notmatch '\\(\.git|\.vs|obj|bin)($|\\)' -and
        $_.FullName -notmatch '\\backup[^\\]*($|\\)' -and

        # 排除以 backup 开头的 .ps1 文件
        -not ($_.Extension -eq ".ps1" -and $_.Name.ToLower().StartsWith("backup")) -and

        # 过滤长路径
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

# === 确保 .gitignore 存在 ===
$gitignorePath = Join-Path $projectPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
@"
.vs/
x64/
Debug/
Release/
backup*/
*.tmp
*.log
"@ | Out-File -Encoding UTF8 $gitignorePath
}

# === Git 操作（防止 pull 卡住） ===
# 1. stash 当前所有变更（含未跟踪文件）
git stash push --include-untracked -m "Auto-stash before backup_and_push"

# 2. 拉取最新
git pull --rebase origin main

# 3. 恢复之前的变更
git stash pop

# 4. 提交
$commitMessage = Read-Host ">>> 请输入提交说明（默认：Auto backup $timestamp）"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Auto backup $timestamp"
}

# 添加白名单类型的新文件（存在才 add，避免 fatal）
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
