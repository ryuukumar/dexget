

$debugmode = $false

function Write-Dbg {
	param (
		[string]$text,
		[string]$level
	)

	if (($level -eq "debug" -or $level -eq "info")) {
		if ($debugmode -eq $true) {
			if ($level -eq "debug") { Write-Host "[DEBUG]`t`t$text" -ForegroundColor Green }
			else { Write-Host "[INFO]`t`t$text" -ForegroundColor Blue }
		} else { return }
	}
	elseif ($level -eq "warning") { Write-Host "[WARNING]`t$text" -ForegroundColor Yellow }
	elseif ($level -eq "error") { Write-Host "[ERROR]`t`t$text" -ForegroundColor Red }
	else { Write-Host "$text" }
}

$writedbgstr = ${function:Write-Dbg}.ToString()