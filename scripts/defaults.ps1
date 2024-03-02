

function Update-Settings ($default, $current) {
	$changed = $false
    foreach ($key in $default.Keys) {
        if (-not $current.ContainsKey($key)) {
            $current[$key] = $default[$key]
			$changed = $true
        } elseif ($default[$key].GetType().IsEquivalentTo([hashtable])) {
            if (Update-Settings -default $default[$key] -current $current[$key] -eq $true) {
				$changed = $true
			}
        }
    }
	return $changed
}

function ConvertTo-Hashtable {
    param (
        [PSCustomObject]$object
    )

    $hash = @{}
    $object.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [PSCustomObject]) {
            $hash[$_.Name] = ConvertTo-Hashtable -object $_.Value
        } else {
            $hash[$_.Name] = $_.Value
        }
    }

    return $hash
}


[hashtable]$defsettings = @{
	'general' = @{
		'manga-language' = "en"
		'enable-cloud-saving' = $false
		'manga-save-directory' = "Manga"
		'cloud-save-directory' = ""
		'update-on-launch' = $false
		'debug-mode' = $false
	}
	'performance' = @{
		'maximum-simultaneous-downloads' = 25
		'maximum-simultaneous-conversions' = 1
		'maximum-simultaneous-pdf-conversions' = 1
		'pdf-method' = 'magick'
	}
	'manga-quality' = @{
		'page-width' = 1000
		'grayscale' = $false
		'quality' = "low"
	}
}

function Load-Settings {
	[hashtable]$settings
	if (-not (Test-Path "preferences.json")) {
		$defsettings | ConvertTo-Json | Out-File 'preferences.json'
		write-dbg "preferences.json not found, so it was created with default settings." -level "warning"
	}
	else {
		$settings = ConvertTo-Hashtable (Get-Content 'preferences.json' | ConvertFrom-Json)
		if (Update-Settings -default $defsettings -current $settings -eq $true) {
			write-dbg "preferences.json was updated with some new settings. Please rerun DexGet for normal execution." -level "warning"
			$settings | ConvertTo-Json | Out-File 'preferences.json'
			exit
		}
	}
	return $settings
}

