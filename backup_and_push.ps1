# ====== ������ ======
$projectPath = "D:\Ccode\MiddleSwitchCpp"
$allowedExt  = @(".cpp", ".h", ".rc", ".ico", ".png", ".jpg", ".md", ".txt", ".bat", ".ps1")
$maxSizeMB   = 50
# ====== ���ý��� ======

# === ��ȫ�� ===
if ((Get-Location).ProviderPath -ne $projectPath) {
    Write-Host "���󣺵�ǰĿ¼���� $projectPath" -ForegroundColor Red
    Write-Host "�������У�cd `"$projectPath`"" -ForegroundColor Yellow
    exit
}

# ��������Ŀ¼
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "backup_$timestamp"
Write-Host ">>> �������ر���: $backupDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $backupDir | Out-Null

Write-Host ">>> ��ʼ����Դ������Դ�ļ�..." -ForegroundColor Cyan
Get-ChildItem -Path $projectPath -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object {
        -not $_.PSIsContainer -and
        $allowedExt -contains $_.Extension.ToLower() -and
        $_.Length -lt ($maxSizeMB * 1MB) -and

        # �ų�Ŀ¼
        $_.FullName -notmatch '\\(\.git|\.vs|obj|bin)($|\\)' -and
        $_.FullName -notmatch '\\backup[^\\]*($|\\)' -and

        # �ų��� backup ��ͷ�� .ps1 �ļ�
        -not ($_.Extension -eq ".ps1" -and $_.Name.ToLower().StartsWith("backup"))
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

# ===== Git �ύ��������ʽ =====
# ȷ�� .gitignore �����޹�Ŀ¼
$gitignorePath = Join-Path $projectPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    @"
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
"@ | Out-File -Encoding UTF8 $gitignorePath
}

git pull --rebase origin main

$commitMessage = Read-Host ">>> �������ύ˵����Ĭ�ϣ�Auto backup $timestamp��"
if ([string]::IsNullOrWhiteSpace($commitMessage)) {
    $commitMessage = "Auto backup $timestamp"
}

# ���ݴ��Ѹ����ļ����޸���ɾ��
git add -u
# ����Ӱ��������͵����ļ�
foreach ($ext in $allowedExt) {
    git add "*$ext"
}

git commit -m "$commitMessage"
git push

Write-Host ">>> ������������ɣ�" -ForegroundColor Green
