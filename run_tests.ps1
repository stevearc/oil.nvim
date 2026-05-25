#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Create required directories
$dirs = @(
    ".testenv/config/nvim",
    ".testenv/data/nvim",
    ".testenv/state/nvim",
    ".testenv/run/nvim",
    ".testenv/cache/nvim"
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# Plugin directory
$PLUGINS = ".testenv/data/nvim-data/site/pack/plugins/start"

# Ensure plenary.nvim is present
$plenaryPath = Join-Path $PLUGINS "plenary.nvim"
if (-Not (Test-Path $plenaryPath)) {
    git clone --depth=1 https://github.com/nvim-lua/plenary.nvim.git $plenaryPath
} else {
    Push-Location $plenaryPath
    git pull
    Pop-Location
}

# Set environment variables
$env:XDG_CONFIG_HOME = ".testenv/config"
$env:XDG_DATA_HOME   = ".testenv/data"
$env:XDG_STATE_HOME  = ".testenv/state"
$env:XDG_RUNTIME_DIR = ".testenv/run"
$env:XDG_CACHE_HOME  = ".testenv/cache"

# Run Neovim tests
$nvimArgs = @(
    "--headless",
    "-u", "./tests/minimal_init.lua",
    "-c", "PlenaryBustedDirectory $($args[0] ?? 'tests') { minimal_init = './tests/minimal_init.lua' }"
)

nvim @nvimArgs

Write-Host "Success"

