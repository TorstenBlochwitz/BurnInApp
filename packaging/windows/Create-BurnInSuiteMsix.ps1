param(
	[string]$Configuration = "Release",
	[string]$RuntimeIdentifier = "win-x64",
	[string]$PackageName = "InfraSolid.BurnInSuite",
	[string]$DisplayName = "InfraSolid BurnIn Suite",
	[string]$Publisher = "CN=BurnInSuiteTest",
	[string]$PublisherDisplayName = "InfraSolid",
	[string]$PackageVersion = "3.2.2.0",
	[string]$Description = "BurnIn App and BurnIn Maintenance App packaged together.",
	[string]$OutputDirectory = "artifacts/packages/windows",
	[string]$CertificatePath = "",
	[string]$CertificatePassword = "",
	[switch]$CreateTestCertificate,
	[switch]$SelfContained = $true
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
	return (Resolve-Path (Join-Path $PSScriptRoot "..\.."))
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

function New-PlaceholderLogo {
	param(
		[string]$Path,
		[int]$Width,
		[int]$Height,
		[string]$Title,
		[string]$Subtitle,
		[string]$BackgroundHtml,
		[string]$ForegroundHtml = '#FFFFFF'
	)

	Add-Type -AssemblyName System.Drawing

	$bitmap = New-Object System.Drawing.Bitmap $Width, $Height
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($BackgroundHtml))
	$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

	$titleFontSize = [Math]::Max(12, [int]($Height / 7))
	$subtitleFontSize = [Math]::Max(8, [int]($Height / 13))
	$titleFont = New-Object System.Drawing.Font('Segoe UI', $titleFontSize, [System.Drawing.FontStyle]::Bold)
	$subtitleFont = New-Object System.Drawing.Font('Segoe UI', $subtitleFontSize, [System.Drawing.FontStyle]::Regular)
	$brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($ForegroundHtml))
	$stringFormat = New-Object System.Drawing.StringFormat
	$stringFormat.Alignment = [System.Drawing.StringAlignment]::Center
	$stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

	$titleRect = New-Object System.Drawing.RectangleF(0, $Height * 0.22, $Width, $Height * 0.28)
	$subtitleRect = New-Object System.Drawing.RectangleF(0, $Height * 0.55, $Width, $Height * 0.18)

	$graphics.DrawString($Title, $titleFont, $brush, $titleRect, $stringFormat)
	if (-not [string]::IsNullOrWhiteSpace($Subtitle))
	{
		$graphics.DrawString($Subtitle, $subtitleFont, $brush, $subtitleRect, $stringFormat)
	}

	$bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

	$brush.Dispose()
	$titleFont.Dispose()
	$subtitleFont.Dispose()
	$graphics.Dispose()
	$bitmap.Dispose()
}

function New-TestCertificate {
	param(
		[string]$PublisherName,
		[string]$DestinationPath,
		[string]$Password
	)

	$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
	$cert = New-SelfSignedCertificate -Type Custom -Subject $PublisherName -KeyUsage DigitalSignature -CertStoreLocation 'Cert:\CurrentUser\My'
	Export-PfxCertificate -Cert $cert -FilePath $DestinationPath -Password $securePassword | Out-Null
	return $DestinationPath
}

$repoRoot = Get-RepoRoot
$outputRoot = Join-Path $repoRoot $OutputDirectory
$publishRoot = Join-Path $repoRoot 'artifacts\publish\windows-msix'
$stagingRoot = Join-Path $outputRoot 'staging'
$packageRoot = Join-Path $outputRoot 'package'
$assetRoot = Join-Path $stagingRoot 'Assets'

Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $packageRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingRoot, $packageRoot, $assetRoot, $publishRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'BurnInApp'), (Join-Path $stagingRoot 'BurnInBoardMaintenanceApp') | Out-Null

$burnInAppPublish = Join-Path $publishRoot 'BurnInApp'
$maintenancePublish = Join-Path $publishRoot 'BurnInBoardMaintenanceApp'

$publishCommon = @('-c', $Configuration, '-r', $RuntimeIdentifier, '-o')
$selfContainedValue = if ($SelfContained) { 'true' } else { 'false' }

dotnet publish (Join-Path $repoRoot 'BurnInApp\BurnInApp.csproj') @publishCommon $burnInAppPublish '--self-contained' $selfContainedValue
dotnet publish (Join-Path $repoRoot 'BurnInBoardMaintenanceApp\BurnInBoardMaintenanceApp.csproj') @publishCommon $maintenancePublish '--self-contained' $selfContainedValue

Copy-Item (Join-Path $burnInAppPublish '*') (Join-Path $stagingRoot 'BurnInApp') -Recurse -Force
Copy-Item (Join-Path $maintenancePublish '*') (Join-Path $stagingRoot 'BurnInBoardMaintenanceApp') -Recurse -Force

New-PlaceholderLogo -Path (Join-Path $assetRoot 'StoreLogo.png') -Width 50 -Height 50 -Title 'BI' -Subtitle '' -BackgroundHtml '#0F4C81'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInApp-Square44x44Logo.png') -Width 44 -Height 44 -Title 'BI' -Subtitle '' -BackgroundHtml '#0F4C81'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInApp-Square150x150Logo.png') -Width 150 -Height 150 -Title 'BurnIn' -Subtitle 'App' -BackgroundHtml '#0F4C81'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInApp-Wide310x150Logo.png') -Width 310 -Height 150 -Title 'BurnIn' -Subtitle 'App' -BackgroundHtml '#0F4C81'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInApp-Square310x310Logo.png') -Width 310 -Height 310 -Title 'BurnIn' -Subtitle 'App' -BackgroundHtml '#0F4C81'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInMaintenance-Square44x44Logo.png') -Width 44 -Height 44 -Title 'BM' -Subtitle '' -BackgroundHtml '#6A1B9A'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInMaintenance-Square150x150Logo.png') -Width 150 -Height 150 -Title 'BurnIn' -Subtitle 'Maintenance' -BackgroundHtml '#6A1B9A'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInMaintenance-Wide310x150Logo.png') -Width 310 -Height 150 -Title 'BurnIn' -Subtitle 'Maintenance' -BackgroundHtml '#6A1B9A'
New-PlaceholderLogo -Path (Join-Path $assetRoot 'BurnInMaintenance-Square310x310Logo.png') -Width 310 -Height 310 -Title 'BurnIn' -Subtitle 'Maintenance' -BackgroundHtml '#6A1B9A'

$manifestTemplatePath = Join-Path $repoRoot 'packaging\windows\BurnInSuite.Package.appxmanifest'
$manifestContent = Get-Content $manifestTemplatePath -Raw
$manifestContent = $manifestContent.Replace('__PACKAGE_NAME__', $PackageName)
$manifestContent = $manifestContent.Replace('__PUBLISHER__', $Publisher)
$manifestContent = $manifestContent.Replace('__PACKAGE_VERSION__', $PackageVersion)
$manifestContent = $manifestContent.Replace('__DISPLAY_NAME__', $DisplayName)
$manifestContent = $manifestContent.Replace('__PUBLISHER_DISPLAY_NAME__', $PublisherDisplayName)
$manifestContent = $manifestContent.Replace('__DESCRIPTION__', $Description)
Set-Content -Path (Join-Path $stagingRoot 'AppxManifest.xml') -Value $manifestContent -Encoding UTF8

$makeAppxPath = Get-ToolPath 'makeappx.exe'
if (-not $makeAppxPath)
{
	throw 'makeappx.exe was not found. Install the Windows SDK / MSIX Packaging Tools before creating the package.'
}

$packageFileName = "BurnInSuite-$PackageVersion-$RuntimeIdentifier.msix"
$packagePath = Join-Path $packageRoot $packageFileName
& $makeAppxPath pack /d $stagingRoot /p $packagePath /o | Write-Host

if ($CreateTestCertificate)
{
	if ([string]::IsNullOrWhiteSpace($CertificatePassword))
	{
		$CertificatePassword = 'BurnInSuiteTest123!'
	}

	$CertificatePath = New-TestCertificate -PublisherName $Publisher -DestinationPath (Join-Path $packageRoot 'BurnInSuite-TestCertificate.pfx') -Password $CertificatePassword
}

if (-not [string]::IsNullOrWhiteSpace($CertificatePath))
{
	$signtoolPath = Get-ToolPath 'signtool.exe'
	if (-not $signtoolPath)
	{
		throw 'signtool.exe was not found. Install the Windows SDK before signing the package.'
	}

	if ([string]::IsNullOrWhiteSpace($CertificatePassword))
	{
		throw 'CertificatePassword is required when CertificatePath is supplied.'
	}

	& $signtoolPath sign /fd SHA256 /f $CertificatePath /p $CertificatePassword $packagePath | Write-Host
}
else
{
	Write-Warning 'The MSIX package was created but not signed. Windows installation requires a signed package.'
}

Write-Host "MSIX package created at $packagePath"
