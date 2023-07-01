

### -----------------------------------------
### PROGRESS-BLIP
### -----------------------------------------

function Progress-Bar {
    [CmdletBinding()]
    param (
        [Parameter(mandatory=$false)][string]$command,
        [Parameter(mandatory=$true)][int]$size,
        [Parameter(mandatory=$true)][string]$dlfile,
        [Parameter(mandatory=$false)][string]$pretext,
        [Parameter(mandatory=$false)][bool]$EndWithNewline = $false,
        [Parameter(mandatory=$false)][int]$BarLength = 50,
        [Parameter(Mandatory=$false)][bool]$IsDirectory = $false,
        [Parameter(Mandatory=$false)][scriptblock]$scriptblock,
        [Parameter(Mandatory=$false)]$argumentlist
    )

BEGIN {
    function Get-DirectorySize {
		[CmdletBinding()]
		$TargetDir = $dlfile

		$size = 0
		Get-ChildItem $TargetDir | ForEach-Object {
			$size += $(get-item "$targetdir\$($_.name)").Length
            #write-host "+$($_.Length)" -NoNewline
		}
		#write-host "=$size"
		return $size
	}
    #$fracprog = @(' ', '$([char]0x258c)')
    $units = @{
        "b" = 1
        "Kb" = 1e-3
        "Mb" = 1e-6
        "Gb" = 1e-9
    }
}

PROCESS {

    $name = "$(get-date)"
    [int]$i = 0
    [float]$currentperc = 0.0

    if (Test-Path "$dlfile") {
        remove-item "$dlfile"
    }

    write-host "`r" -NoNewline

    $unit
    $multiplier=1
    foreach ($key in $units.Keys) {
        if ($size -gt 0.9 * (1/$units[$key])) {
            $unit = $key
            $multiplier = $units[$key]
            break
        }
    }

    if ($IsDirectory) {
        $job = start-job -scriptblock $scriptblock -name "$name" -ArgumentList $argumentlist
    } else {
        $job = start-job -scriptblock {param($cmd) Invoke-Expression $cmd} -name "$name" -ArgumentList @($args)
    }

    while($currentperc -ne 1) {
        if (Test-Path "$dlfile") {
            if ($IsDirectory) {
                $currentperc = $(Get-DirectorySize) / $size
            } else {
                $currentperc = $((Get-Item "$dlfile").length) / $size
            }
            
            $fw = ("{0:F2}" -f ($size * $multiplier)).length
            $output = "{0,${fw}:F2}/{1:F2} {2} | " -f ($(Get-DirectorySize) * $multiplier), ($size * $multiplier), $unit
            if (($currentperc * $BarLength) + 2 -ge $BarLength) {
                foreach ($n in 0..($BarLength+1)) {$output += "$([char]0x2588)"}
            }
            else {
                foreach ($n in 0..($currentperc * $BarLength)) {$output += "$([char]0x2588)"}
                if (($currentperc * $BarLength) - [int]($currentperc * $BarLength) -gt 0.3) { $output += "$([char]0x258c)" }
                else { $output += ' ' }
                foreach ($n in (($currentperc * $BarLength)+1)..$BarLength) {$output += " "}
            }

            Write-Host "`r${pretext}${output}" -nonewline
        }
        else {
            Write-Host "`r${pretext} (waiting)" -nonewline
        }
        start-sleep -Milliseconds 100

        $BarLength = ([int]$($Host.UI.RawUI.WindowSize.Width)) - ($pretext.length + 20)

        #$job.ChildJobs[0].Error
        #$job.ChildJobs[0].ChildJobs[0].Error

        if ((get-job -name "$name").state -eq "Completed") {
            break
        }
    }

    $clrline = '{0}' -f (' ' * ($Host.UI.RawUI.WindowSize.Width - 1))
    Write-Host "`r${clrline}" -NoNewline
    #Write-Host "`r${pretext}done$($EndWithNewline ? "`n" : '')" -NoNewline  
    Write-Host "`r" -NoNewline  

    $joboutput = $job.ChildJobs[0].Output
    Stop-Job -Name "$name"

    return $joboutput
}

END {}

}



### -----------------------------------------
### END
### -----------------------------------------