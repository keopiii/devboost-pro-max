# git-setup.ps1
# Automates Git repo initialization, SSH setup, and GitHub push
# Run in PowerShell as: powershell -ExecutionPolicy Bypass -File .\git-setup.ps1

Write-Host "🚀 Git & GitHub Automation Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Ask for project folder
$projectPath = Read-Host "Enter the full path of your project folder"
if (!(Test-Path $projectPath)) {
    Write-Host "❌ The specified path does not exist. Exiting..." -ForegroundColor Red
    exit
}

Set-Location $projectPath
Write-Host "✅ Working in: $projectPath" -ForegroundColor Green

# Ask for GitHub repository URL
$repoURL = Read-Host "Enter your GitHub repository SSH URL (e.g., git@github.com:username/repo.git)"

# Configure Git username & email if not set
$gitUser = git config --global user.name
$gitEmail = git config --global user.email

if (-not $gitUser) {
    $gitUser = Read-Host "Enter your Git username"
    git config --global user.name "$gitUser"
}

if (-not $gitEmail) {
    $gitEmail = Read-Host "Enter your Git email"
    git config --global user.email "$gitEmail"
}

Write-Host "✅ Git user: $gitUser, email: $gitEmail" -ForegroundColor Green

# Ask if user wants SSH key setup
$useSSH = Read-Host "Do you want to set up SSH for GitHub? (yes/no)"
if ($useSSH -eq "yes") {
    $sshPath = "$env:USERPROFILE\.ssh\id_ed25519"
    if (!(Test-Path $sshPath)) {
        Write-Host "🔐 Generating SSH key..." -ForegroundColor Yellow
        ssh-keygen -t ed25519 -C "$gitEmail" -f $sshPath -N ""
        Write-Host "`n✅ SSH key generated!" -ForegroundColor Green
    } else {
        Write-Host "✅ SSH key already exists. Skipping generation." -ForegroundColor Green
    }

    Write-Host "`nYour public key (add this to GitHub → Settings → SSH and GPG keys → New Key):" -ForegroundColor Cyan
    Get-Content "$sshPath.pub"
    Read-Host "`nPress ENTER after you have added the key to GitHub"

    # Test SSH connection
    Write-Host "`n🔍 Testing GitHub SSH connection..." -ForegroundColor Yellow
    ssh -T git@github.com
    Write-Host "`n✅ SSH connection test complete." -ForegroundColor Green
}

# Initialize Git repo
if (!(Test-Path ".git")) {
    git init
    Write-Host "✅ Initialized new Git repository." -ForegroundColor Green
} else {
    Write-Host "✅ Git repository already initialized." -ForegroundColor Green
}

# Add remote
git remote remove origin 2>$null
git remote add origin $repoURL
Write-Host "✅ Remote set to $repoURL" -ForegroundColor Green

# Add, commit, and push
git add .
$commitMsg = Read-Host "Enter commit message"
git commit -m "$commitMsg"
git branch -M main
git push -u origin main

Write-Host "✅ All done! Your project is now on GitHub." -ForegroundColor Green
