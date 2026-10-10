$root = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $root 'BurnInApp'
$targetDir = Join-Path $root 'BurnIn.Shared'
$files = @(
	'ADC_ADS1115.cs',
	'ADS1115.cs',
	'AnalogMux.cs',
	'BurnInAction.cs',
	'BurnInActionEnum.cs',
	'BurnInDev.cs',
	'BurnInProfile.cs',
	'BurnInSettings.cs',
	'BurnInStatus.cs',
	'BurnInStatusEnum.cs',
	'DCDCConverterBoard.cs',
	'EEPROM_M24C02.cs',
	'I2CMultiplexerPCA9542A.cs',
	'MainBoard.cs',
	'MainBoardKind.cs',
	'MBC_TB.cs',
	'MBC_USB_TCP.cs',
	'PMBusDev.cs',
	'ProfileStatusEnum.cs',
	'SerialNumberHelper.cs',
	'SMBusDev.cs',
	'StatusFile.cs',
	'TempSensor_TMP1075.cs',
	'VDCstatus.cs',
	'VDCStatusEnum.cs'
)

foreach ($file in $files) {
	$sourcePath = Join-Path $sourceDir $file
	$targetPath = Join-Path $targetDir $file
	$content = Get-Content -Raw $sourcePath
	$content = $content -replace 'namespace BurnInApp', 'namespace BurnIn.Shared'
	Set-Content -Path $targetPath -Value $content
}
