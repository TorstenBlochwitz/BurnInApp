param(
	[string]$Publisher = 'CN=BurnInSuiteTest',
	[string]$OutputPath = 'artifacts/packages/windows/BurnInSuite-TestCertificate.pfx',
	[string]$Password = 'BurnInSuiteTest123!'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$certificatePath = Join-Path $repoRoot $OutputPath
$directory = Split-Path -Parent $certificatePath
if (-not (Test-Path $directory))
{
	New-Item -ItemType Directory -Path $directory | Out-Null
}

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$cert = New-SelfSignedCertificate -Type Custom -Subject $Publisher -KeyUsage DigitalSignature -CertStoreLocation 'Cert:\CurrentUser\My'
Export-PfxCertificate -Cert $cert -FilePath $certificatePath -Password $securePassword | Out-Null
Write-Host "Created test certificate at $certificatePath"
Write-Host 'Import the certificate into Trusted People on the target machine before installing the test-signed MSIX.'
