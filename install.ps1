# Claude Code Installer for Windows
# Usage: irm https://claude.ai/install.ps1 | iex

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ClaudePackage = '@anthropic-ai/claude-code'

function Write-Header {
    Write-Host ""
    Write-Host "  Claude Code Installer" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "  → $Message" -ForegroundColor White
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ! $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-NodeVersion {
    try {
        $raw = & node --version 2>$null
        if ($raw -match 'v(\d+)') { return [int]$Matches[1] }
    } catch {}
    return 0
}

function Get-NpmVersion {
    try {
        $raw = & npm --version 2>$null
        if ($raw -match '(\d+)') { return [int]$Matches[1] }
    } catch {}
    return 0
}

function Install-NodeViaWinget {
    if (-not (Test-CommandExists 'winget')) { return $false }
    Write-Step "Installing Node.js via winget..."
    try {
        winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent | Out-Null
        # Refresh PATH so node/npm are available in this session
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        return (Test-CommandExists 'node')
    } catch {
        return $false
    }
}

function Install-NodeViaNvm {
    # nvm-windows
    if (-not (Test-CommandExists 'nvm')) { return $false }
    Write-Step "Installing Node.js LTS via nvm..."
    try {
        nvm install lts | Out-Null
        nvm use lts | Out-Null
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        return (Test-CommandExists 'node')
    } catch {
        return $false
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Header

# 1. Node.js check
Write-Step "Checking for Node.js..."

$nodeMajor = Get-NodeVersion
$minNode = 18

if ($nodeMajor -ge $minNode) {
    Write-Success "Node.js v$nodeMajor detected"
} else {
    if ($nodeMajor -gt 0) {
        Write-Warn "Node.js v$nodeMajor is too old (minimum: v$minNode). Attempting upgrade..."
    } else {
        Write-Warn "Node.js not found. Attempting installation..."
    }

    $installed = Install-NodeViaNvm
    if (-not $installed) { $installed = Install-NodeViaWinget }

    if (-not $installed) {
        Write-Err "Could not install Node.js automatically."
        Write-Host ""
        Write-Host "  Please install Node.js $minNode+ from https://nodejs.org and re-run this script." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    $nodeMajor = Get-NodeVersion
    Write-Success "Node.js v$nodeMajor installed"
}

# 2. npm check
Write-Step "Checking for npm..."
if (-not (Test-CommandExists 'npm')) {
    Write-Err "npm not found. Please install Node.js from https://nodejs.org"
    exit 1
}
$npmMajor = Get-NpmVersion
Write-Success "npm v$npmMajor detected"

# 3. Install Claude Code
Write-Step "Installing Claude Code..."
try {
    $npmArgs = @('install', '--global', $ClaudePackage)
    $result = & npm @npmArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw $result
    }
    Write-Success "Claude Code installed successfully"
} catch {
    # Retry with --force in case of peer-dep conflicts
    Write-Warn "Retrying with --force flag..."
    try {
        & npm install --global --force $ClaudePackage 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        Write-Success "Claude Code installed successfully"
    } catch {
        Write-Err "Installation failed: $_"
        Write-Host ""
        Write-Host "  Try running manually:" -ForegroundColor Yellow
        Write-Host "    npm install -g $ClaudePackage" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
}

# 4. Verify
Write-Step "Verifying installation..."
if (Test-CommandExists 'claude') {
    $claudeVersion = & claude --version 2>$null
    Write-Success "claude $claudeVersion is ready"
} else {
    # claude may not be in PATH yet for this session
    Write-Warn "claude command not found in current PATH."
    Write-Host ""
    Write-Host "  Your npm global bin directory may not be in PATH." -ForegroundColor Yellow
    Write-Host "  Run the following to find it and add it manually:" -ForegroundColor Yellow
    Write-Host "    npm config get prefix" -ForegroundColor Cyan
    Write-Host "  Then add <prefix>\bin to your PATH." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Get started: " -ForegroundColor White -NoNewline
Write-Host "claude" -ForegroundColor Cyan
Write-Host "  Docs:        " -ForegroundColor White -NoNewline
Write-Host "https://docs.anthropic.com/claude-code" -ForegroundColor Cyan
Write-Host ""
