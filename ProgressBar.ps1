

### -----------------------------------------
### PROGRESS-BAR
### -----------------------------------------

function Progress-Bar {
    [CmdletBinding()]
    param (
        [Parameter(mandatory=$true)][scriptblock]$scriptblock,
        [Parameter(mandatory=$true)][int]$size,
        [Parameter(mandatory=$true)][scriptblock]$sizeGetter,
        [Parameter(mandatory=$false)][string]$pretext = "",
        [Parameter(mandatory=$false)][bool]$EndWithNewline = $false,
        [Parameter(mandatory=$false)][int]$BarLength = 50,
        [Parameter(mandatory=$false)][int]$UpdateInterval = 100,
        [Parameter(Mandatory=$false)]$argumentlist
    )

BEGIN {
    $units = @{
        "Gb" = 1e-9
        "Mb" = 1e-6
        "Kb" = 1e-3
        "b"  = 1
    }

    $unit = $units.GetEnumerator() | Where-Object { $size -gt 0.9 / $_.Value } | Select-Object -First 1
    $multiplier = if($unit) { $unit.Value } else { 1 }
    $unit = if($unit) { $unit.Name } else { "b" }
}

PROCESS {

    $name = "$(get-date)"

    [float]$currentperc = 0.0

    write-host "`r" -NoNewline

    $job = Start-Job -ScriptBlock $scriptblock -Name "$name" -ArgumentList $argumentlist

    while($currentperc -ne 1) {
        $currentSize = & $sizeGetter
        $currentperc = $currentSize / $size
        
        $fw = ("{0:F2}" -f ($size * $multiplier)).length
        $output = "{0,${fw}:F2}/{1:F2} {2} | " -f ($currentSize * $multiplier), ($size * $multiplier), $unit

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

        start-sleep -Milliseconds $UpdateInterval

        $BarLength = ([int]$($Host.UI.RawUI.WindowSize.Width)) - ($pretext.length + 20)

        if ((get-job -name "$name").state -eq "Completed") {
            break
        }
    }

    $clrline = '{0}' -f (' ' * ($Host.UI.RawUI.WindowSize.Width - 1))
    Write-Host "`r${clrline}" -NoNewline
    Write-Host "`r" -NoNewline  

    $joboutput = $job | Receive-Job -Wait
    Remove-Job -Name "$name"

    return $joboutput
}

END {}

}

### -----------------------------------------
### END
### -----------------------------------------
