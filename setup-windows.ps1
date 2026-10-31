param([switch]$WithBrowser)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed (exit $LASTEXITCODE): $Command $($Arguments -join ' ')"
    }
}

try {
    Write-Host '[1/5] Checking Python and Node.js...' -ForegroundColor Cyan
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw 'Install Python 3.11+ with Add Python to PATH, then restart VS Code.'
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
        throw 'Install Node.js 20+ with npm (20.19+ or newer LTS recommended), then restart VS Code.'
    }
    Invoke-Checked -Command 'python' -Arguments @('-c', "import sys; assert sys.version_info >= (3,11), 'Python 3.11+ is required'; print(sys.version.split()[0])")
    Invoke-Checked -Command 'node' -Arguments @('-e', "if(Number(process.versions.node.split('.')[0]) < 20) { throw new Error('Node.js 20+ is required'); } console.log(process.version)")

    Write-Host '[2/5] Preparing Python environment...' -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath '.venv\Scripts\python.exe')) {
        Invoke-Checked -Command 'python' -Arguments @('-m', 'venv', '.venv')
    }
    $projectPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    Invoke-Checked -Command $projectPython -Arguments @('-c', "import sys; assert sys.version_info >= (3,11), 'Existing .venv requires Python 3.11+'")
    Invoke-Checked -Command $projectPython -Arguments @('-m', 'pip', 'install', '--disable-pip-version-check', '-e', '.[test]')
    Invoke-Checked -Command $projectPython -Arguments @('-m', 'pip', 'check')

    Write-Host '[3/5] Installing frontend dependencies...' -ForegroundColor Cyan
    Push-Location -LiteralPath 'frontend'
    try {
        Invoke-Checked -Command 'npm.cmd' -Arguments @('ci', '--no-audit', '--no-fund')
        Invoke-Checked -Command 'npm.cmd' -Arguments @('ls', '--depth=0')
        Write-Host '[4/5] Building frontend...' -ForegroundColor Cyan
        Invoke-Checked -Command 'npm.cmd' -Arguments @('run', 'build')
        if ($WithBrowser) {
            Invoke-Checked -Command 'npx.cmd' -Arguments @('playwright', 'install', 'chromium')
        }
    } finally { Pop-Location }

    Write-Host '[5/5] Preparing SQLite and checking local files...' -ForegroundColor Cyan
    Invoke-Checked -Command $projectPython -Arguments @('scripts/check_local.py', '--init-db')
    Write-Host 'Setup complete. Run .\start-local.cmd. The launcher prints your configured local URL.' -ForegroundColor Green
    Write-Host 'No Docker, MySQL, hosting or API key is required. Existing .env and database are preserved.'
} catch {
    Write-Host ('Setup failed: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Fix the reported error, then run this script again. Existing projects are preserved.'
    exit 1
}
