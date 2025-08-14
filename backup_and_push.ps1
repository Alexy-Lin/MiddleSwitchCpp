# ===== ������ =====
$projectPath = "D:\Ccode\MiddleSwitchCpp"
$allowedExt  = @(".cpp", ".h", ".rc", ".ico", ".png", ".jpg", ".md", ".txt", ".bat", ".ps1")
$maxSizeMB   = 50
# ===== ���ý��� =====

# === ������ ===
if ((Get-Location).ProviderPath -ne $projectPath) {
    Write-Host "���󣺵�ǰĿ¼���� $projectPath" -ForegroundColor Red
    Write-Host "�������У�cd `"$projectPath`"" -ForegroundColor Yellow
    exit
}

# === �Զ�ά�� .gitignore ===
$gitignorePath = Join-Path $projectPath ".gitignore"
$ignoreRules = @"
# VS ����
.vs/

# �������
x64/
Debug/
Release/

# ����Ŀ¼
backup*/

# ��ʱ�ļ�
*.tmp
*.log

# ϵͳ�ļ�
Thumbs.db
Desktop.ini
"@

if (-not (Test-Path $gitignorePath)) {
    $ignoreRules | Out-File -Encoding UTF8 $gitignorePath
    Write-Host "�Ѵ����µ� .gitignore" -ForegroundColor Green
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
        Write-Host ".gitignore �Ѹ��£����ȱʧ����" -ForegroundColor Yellow
    }
    else {
        Write-Host ".gitignore �ѷ���Ԥ�ڹ���" -ForegroundColor Cyan
    }
}

# === ��������Ŀ¼ ===
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "backup_$timestamp"
Write-Host ">>> �������ر���: $backupDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $backupDir | Out-Null

Write-Host ">>> ��ʼ����Դ������Դ�ļ�..." -ForegroundColor Cyan
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
        Write-Host "����: $($_.FullName)" -ForegroundColor Gray
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
            Write-Warning "������ռ�û򲻿ɶ��ļ�: $($_.FullName)"
        }
    }

# === Git ͬ������ȫ���� ===
git add -u   # �ݴ��Ѹ��ٵ��޸�/ɾ��
git stash push -m "Auto-stash before backup_and_push"  # �� stash �Ѹ��ٱ��
git pull --rebase origin main
git stash pop

# �ύ˵��
$commitMessage = Read-Host ">>> �������ύ˵����Ĭ�ϣ�Auto backup $timestamp��"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Auto backup $timestamp"
}

# �������ύ���ļ������ڲ� add��
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

Write-Host ">>> ������������ɣ�" -ForegroundColor Green
