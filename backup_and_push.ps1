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

        # �ų�Ŀ¼
        $_.FullName -notmatch '\\(\.git|\.vs|obj|bin)($|\\)' -and
        $_.FullName -notmatch '\\backup[^\\]*($|\\)' -and

        # �ų��� backup ��ͷ�� .ps1 �ļ�
        -not ($_.Extension -eq ".ps1" -and $_.Name.ToLower().StartsWith("backup")) -and

        # ���˳�·��
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

# === ȷ�� .gitignore ���� ===
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

# === Git ��������ֹ pull ��ס�� ===
# 1. stash ��ǰ���б������δ�����ļ���
git stash push --include-untracked -m "Auto-stash before backup_and_push"

# 2. ��ȡ����
git pull --rebase origin main

# 3. �ָ�֮ǰ�ı��
git stash pop

# 4. �ύ
$commitMessage = Read-Host ">>> �������ύ˵����Ĭ�ϣ�Auto backup $timestamp��"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Auto backup $timestamp"
}

# ��Ӱ��������͵����ļ������ڲ� add������ fatal��
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
