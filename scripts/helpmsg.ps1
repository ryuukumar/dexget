
function Write-HelpMsg {
	$commands = [ordered]@{
		'--all, -a' = 'Download all messages'
		'--cloud, -C' = 'Save the downloaded chapters in the cloud (if enabled)'
		'--continue, -c' = 'When prompted about existing chapters, continue the download anyway'
		'--dlchaps X, -d X' = 'Download X chapters'
		'--help' = 'Prints this message'
		'--jsonprogress, -j' = 'Show progress via JSON'
		'--no-banner' = 'Do not show banner'
		'--start X, -s X' = 'Start from chapter X'
	}
	
	Write-Box "DexGet v$VERSION`n@ryuukumar on GitHub`nhttps://github.com/ryuukumar/dexget" -center $true
	Write-Host ""
	Write-Host "Usage:`n`n`t./dexget.ps1 <link> [-acCdjs --all --cloud --continue --dlchaps --help --jsonprogress --no-banner --start]`n"

	foreach ($item in $commands.GetEnumerator()) {
		$key = $item.Key
		$value = $item.Value
	
		Write-Host "$key" -ForegroundColor Green
		Write-Host "$value`n"
	}
}