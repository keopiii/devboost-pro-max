<#
USAGE (PowerShell, run from your project folder):
  Set-ExecutionPolicy Bypass -Scope Process -Force
  .\git-auto-setup.ps1 -RepoName "devboost-pro-max" -GitUser "keopiii" -GitEmail "keopiii.kanji@gmail.com" -Visibility "public" -UseSSH "auto"

Optional params:
  -Token "<YOUR_GITHUB_PAT>"              # Needed for auto-creating repo and auto-adding SSH key
  -InitFiles $true/$false                 # Add README, LICENSE(MIT), .gitignore (default: $true)
  -Path "C:\path\to\project"              # Default: current directory
  -UseSSH "auto"|"yes"|"no"               # Default: auto
  -Visibility "public"|"private"          # Default: public
#>

param(
  [string]$RepoName = "devboost-pro-max",
  [string]$GitUser = "keopiii",
  [string]$GitEmail = "keopiii.kanji@gmail.com",
  [string]$Visibility = "public",
  [string]$UseSSH = "auto",
  [string]$Token = "",
  [string]$Path = "",
  [bool]$InitFiles = $true
)

function Fail($msg){ Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# Move into project path
if ([string]::IsNullOrWhiteSpace($Path)) { $Path = (Get-Location).Path }
if (-not (Test-Path $Path)) { Fail "Path not found: $Path" }
Set-Location $Path

# Check git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail "git is not installed or not on PATH. Install Git for Windows and retry."
}

# Configure Git identity (global if not set)
$existingName = git config --global user.name 2>$null
$existingEmail = git config --global user.email 2>$null
if (-not $existingName) { git config --global user.name "$GitUser" | Out-Null }
if (-not $existingEmail) { git config --global user.email "$GitEmail" | Out-Null }

# Helper: write UTF-8 without BOM (for Windows PowerShell)
Add-Type -AssemblyName "System.Text.Encoding"
function Write-Utf8NoBom {
  param([string]$Path,[string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# Initialize repo if needed
if (-not (Test-Path ".git")) {
  git init | Out-Null
}

# Create starter files (optional)
if ($InitFiles) {
  $year = (Get-Date).Year
  $readme = "# $RepoName`r`n`r`nCreated by automated setup."
  $gitignore = @"
node_modules/
dist/
build/
.vscode/
.DS_Store
*.log
"@
  $license = @"
MIT License

Copyright (c) $year $GitUser

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the ""Software""), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"@
  if (-not (Test-Path "README.md")) { Write-Utf8NoBom -Path "README.md" -Content $readme }
  if (-not (Test-Path ".gitignore")) { Write-Utf8NoBom -Path ".gitignore" -Content $gitignore }
  if (-not (Test-Path "LICENSE")) { Write-Utf8NoBom -Path "LICENSE" -Content $license }
}

# Decide transport: SSH or HTTPS
$sshPossible = $false
$sshDir = Join-Path $env:USERPROFILE ".ssh"
$sshPub = Join-Path $sshDir "id_ed25519.pub"
$sshKey = Join-Path $sshDir "id_ed25519"

if ($UseSSH -eq "yes" -or $UseSSH -eq "auto") {
  if (-not (Test-Path $sshPub)) {
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Force -Path $sshDir | Out-Null }
    # Generate key with empty passphrase (adjust if you want a passphrase)
    ssh-keygen -t ed25519 -C "$GitEmail" -N "" -f "$sshKey" | Out-Null
  }
  # Ensure ssh-agent has the key
  Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-Command","Start-SSHAgent -Quiet" -WindowStyle Hidden | Out-Null 2>$null
  try { ssh-add "$sshKey" | Out-Null } catch { }
  $sshPossible = Test-Path $sshPub
}

# Create repo on GitHub via API if Token provided
$createdViaAPI = $false
if ($Token) {
  $apiUri = "https://api.github.com/user/repos"
  $body = @{
    name = $RepoName
    private = ($Visibility -eq "private")
    auto_init = $false
  } | ConvertTo-Json
  try {
    $headers = @{ Authorization = "token $Token"; "User-Agent" = "git-auto-setup" }
    $resp = Invoke-RestMethod -Method Post -Uri $apiUri -Headers $headers -Body $body -ContentType "application/json"
    $createdViaAPI = $true
  } catch {
    Write-Host "Warning: Repo creation via API failed. Ensure the PAT has repo scope and the name is unique." -ForegroundColor Yellow
  }

  # Add SSH key to GitHub if using SSH and key exists
  if ($sshPossible) {
    try {
      $pubKey = Get-Content $sshPub -Raw
      $keyBody = @{ title = "auto-key-$env:COMPUTERNAME"; key = $pubKey } | ConvertTo-Json
      Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/keys" -Headers $headers -Body $keyBody -ContentType "application/json" | Out-Null
    } catch {
      Write-Host "Warning: Adding SSH key via API failed. You can add it manually in GitHub Settings > SSH and GPG keys." -ForegroundColor Yellow
    }
  }
}

# Set remote
$existingRemote = git remote 2>$null
if (-not $existingRemote) {
  if ($sshPossible -and $UseSSH -ne "no") {
    git remote add origin "git@github.com:$GitUser/$RepoName.git"
  } else {
    git remote add origin "https://github.com/$GitUser/$RepoName.git"
  }
} else {
  # Ensure origin URL matches chosen transport
  if ($sshPossible -and $UseSSH -ne "no") {
    git remote set-url origin "git@github.com:$GitUser/$RepoName.git"
  } else {
    git remote set-url origin "https://github.com/$GitUser/$RepoName.git"
  }
}

# Commit and push
git add -A
# Create main branch even if empty
git commit -m "Initial commit" 2>$null | Out-Null
git branch -M main

# Push (may prompt if using HTTPS without PAT stored; with SSH it should just work)
try {
  git push -u origin main
} catch {
  Write-Host "Push failed. If using HTTPS, Git may prompt for credentials. If you prefer SSH, ensure your key is added to GitHub." -ForegroundColor Yellow
}

Write-Host "Done. Repo: https://github.com/$GitUser/$RepoName" -ForegroundColor Green
