param(
	[string]$Configuration = 'LinuxRelease',
	[string]$Platform = 'x86',
	[string]$BundleName = 'BurnInSuite',
	[string]$PackageVersion = '3.2.2',
	[string]$OutputDirectory = 'artifacts/packages/linux'
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
	return (Resolve-Path (Join-Path $PSScriptRoot '..\..'))
}

function Get-ToolPath {
	param([string]$CommandName)

	$command = Get-Command $CommandName -ErrorAction SilentlyContinue
	if ($command)
	{
		return $command.Source
	}

	return $null
}

$repoRoot = Get-RepoRoot
$outputRoot = Join-Path $repoRoot $OutputDirectory
$publishRoot = Join-Path $repoRoot 'artifacts\publish\linux-targz'
$stagingRoot = Join-Path $outputRoot 'staging'
$bundleRoot = Join-Path $stagingRoot $BundleName

Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $outputRoot, $publishRoot, $bundleRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $bundleRoot 'BurnInApp'), (Join-Path $bundleRoot 'BurnInBoardMaintenanceApp') | Out-Null

$burnInAppPublish = Join-Path $publishRoot 'BurnInApp'
$maintenancePublish = Join-Path $publishRoot 'BurnInBoardMaintenanceApp'

dotnet publish (Join-Path $repoRoot 'BurnInApp\BurnInApp.csproj') -c $Configuration -p:Platform=$Platform -o $burnInAppPublish
dotnet publish (Join-Path $repoRoot 'BurnInBoardMaintenanceApp\BurnInBoardMaintenanceApp.csproj') -c $Configuration -p:Platform=$Platform -o $maintenancePublish

Copy-Item (Join-Path $burnInAppPublish '*') (Join-Path $bundleRoot 'BurnInApp') -Recurse -Force
Copy-Item (Join-Path $maintenancePublish '*') (Join-Path $bundleRoot 'BurnInBoardMaintenanceApp') -Recurse -Force

$startBurnInApp = @'
#!/usr/bin/env sh
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec dotnet "$SCRIPT_DIR/BurnInApp/BurnInApp.dll" "$@"
'@

$startMaintenance = @'
#!/usr/bin/env sh
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec dotnet "$SCRIPT_DIR/BurnInBoardMaintenanceApp/BurnInBoardMaintenanceApp.dll" "$@"
'@

$installScript = @'
#!/usr/bin/env sh
set -eu

PREFIX="${1:-/opt/BurnInSuite}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

mkdir -p "$PREFIX"
cp -R "$SCRIPT_DIR/BurnInApp" "$PREFIX/"
cp -R "$SCRIPT_DIR/BurnInBoardMaintenanceApp" "$PREFIX/"
cp "$SCRIPT_DIR/start-burninapp.sh" "$PREFIX/"
cp "$SCRIPT_DIR/start-burninmaintenanceapp.sh" "$PREFIX/"
chmod +x "$PREFIX/start-burninapp.sh" "$PREFIX/start-burninmaintenanceapp.sh"

echo "Installed BurnIn suite into $PREFIX"
echo "Start BurnInApp with: $PREFIX/start-burninapp.sh"
echo "Start BurnInMaintenanceApp with: $PREFIX/start-burninmaintenanceapp.sh"
'@

$readme = @'
BurnIn Suite Linux bundle
=========================

This archive contains both applications:
- BurnInApp
- BurnInBoardMaintenanceApp

Quick start without installation:
- ./start-burninapp.sh
- ./start-burninmaintenanceapp.sh

Install into /opt/BurnInSuite:
- sudo ./install.sh

Install into a custom folder:
- ./install.sh "$HOME/BurnInSuite"
'@

Set-Content -Path (Join-Path $bundleRoot 'start-burninapp.sh') -Value $startBurnInApp -NoNewline
Set-Content -Path (Join-Path $bundleRoot 'start-burninmaintenanceapp.sh') -Value $startMaintenance -NoNewline
Set-Content -Path (Join-Path $bundleRoot 'install.sh') -Value $installScript -NoNewline
Set-Content -Path (Join-Path $bundleRoot 'README.txt') -Value $readme -NoNewline

$tarPath = Get-ToolPath 'tar.exe'
if (-not $tarPath)
{
	throw 'tar.exe was not found. Install Windows tar support or run the packaging step on a machine where tar is available.'
}

$archivePath = Join-Path $outputRoot ("$BundleName-$PackageVersion-linux-$Platform.tar.gz")
if (Test-Path $archivePath)
{
	Remove-Item $archivePath -Force
}

& $tarPath -czf $archivePath -C $stagingRoot $BundleName
Write-Host "tar.gz package created at $archivePath"
