

. "$PSScriptRoot/helpmsg.ps1"

function Parse-Args {
	param (
		[ref]$argsettings,
		$cmdargs
	)

	$i=0
	while ($true) {
		if ($cmdargs[$i]) {
			if ($cmdargs[$i] -eq "--continue" -or $cmdargs[$i] -eq "-c") {
				$argsettings.Value.continue = $true
			}
			if ($cmdargs[$i] -eq "--cloud" -or $cmdargs[$i] -eq "-C") {
				if ($settings.'general'.'enable-cloud-saving' -eq $false) {
					write-dbg "--cloud was passed but cloud saving is disabled in the preferences. The argument will be ignored." -level "warning"
				} else {
					$argsettings.Value.cloud = $true
				}
			}
			if ($cmdargs[$i] -eq "--all" -or $cmdargs[$i] -eq "-a") {
				$argsettings.Value.all = $true
			}
			if ($cmdargs[$i] -eq "--start" -or $cmdargs[$i] -eq "-s") {
				$i++
				if ($cmdargs[$i] -match '^\d+$') {
					$argsettings.Value.startch = $cmdargs[$i]
				}
				else {
					write-dbg "Expected a chapter number after start argument, but got $($cmdargs[$i])." -level "error"
					exit
				}
			}
			if ($cmdargs[$i] -eq "--dlchaps" -or $cmdargs[$i] -eq "-d") {
				$i++
				if ($cmdargs[$i] -match '^\d+$') {
					$argsettings.Value.endch = $cmdargs[$i]
				}
				else {
					write-dbg "Expected a chapter number after end argument, but got $($cmdargs[$i])." -level "error"
					exit
				}
			}
			if ($cmdargs[$i] -eq "--jsonprogress" -or $cmdargs[$i] -eq "-j") {
				$argsettings.value.jsonprogress = $true
			}
			if ($cmdargs[$i] -eq "--no-banner") {
				$argsettings.Value.banner = $false
			}
			if ($cmdargs[$i] -eq "--scanonly" -or $cmdargs[$i] -eq "-l") {
				$argsettings.Value.scanonly = $true
			}
			if ($cmdargs[$i] -eq "--check-latest") {
				if ($argsettings.Value.scanonly) {
					$argsettings.Value.latestonly = $true
				}
				else {
					Write-Dbg "Got argument --check-latest but --scanonly was not specified before it. Ignoring argument." -level "error"
				}
			}
			if ($cmdargs[$i] -eq "--help") {
				Write-HelpMsg
			}
		}
		else { break }
		$i++
	}
}