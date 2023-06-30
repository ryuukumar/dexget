

### -----------------------------------------
### PROGRESS-BLIP
### -----------------------------------------

# <++> @(">   ", "+>  ", "++> ", "<++>", " <++", "  <+", "   <", "    ", "    ")
# |/-\ @("/", "-", "\", "|")

function Progress-Blip {
    [CmdletBinding()]
    param (
        [Parameter(mandatory=$true)][string]$command,
        [Parameter(mandatory=$false)][string]$pretext,
        [Parameter(mandatory=$false)][bool]$EndWithNewline = $false,
        [Parameter(mandatory=$false)][int]$BlipLength = 5
    )

BEGIN {
    function Make-Blip([int]$length) {
        if ($length -lt 10) {
            return @("/", "-", "\", "|")
        }
    
        $bliparr = @()
        [int]$bliplength = $length*0.2
    
        foreach ($n in 0..$($length+$bliplength+$bliplength)) {
            [string]$blip = ""
            foreach ($m in 0..$n) {$blip += ' '}
            $blip += "<"
            foreach ($m in 1..$($bliplength - 2)) {$blip += '='}
            $blip += ">"
            foreach ($m in $($n + $bliplength)..($length+$bliplength)) {$blip += ' '}
            $blip = $blip.Substring($bliplength, $length)
            $bliparr += $blip
        }
    
        return $bliparr
    }
}

PROCESS {
    $bliparray = Make-Blip($BlipLength)
    $name = "$(get-date)"
    [int]$i = 0

    #write-host "${command}"

    $job = start-job -scriptblock {param($cmd) Invoke-Expression $cmd} -name "$name" -ArgumentList @($command)
    $jobstate = (get-job -name "$name").state

#    Write-Host $jobstate

    while($jobstate -eq "Running") {
        write-host "`r$pretext$($bliparray[$i % $bliparray.Length])" -nonewline
        start-sleep -milliseconds 25
        $jobstate = (get-job -name "$name").state
        $i++

        $job.ChildJobs[0].Error
    }

    $clrline = ""
    foreach ($n in 0..$($pretext.length + $bliparray[0].length)) {$clrline += ' '}
    Write-Host "`r${clrline}" -nonewline
    if ($EndWithNewline) {write-host "`r${pretext}done`n" -nonewline}
    else {write-host "`r${pretext}done" -nonewline}

    $joboutput = $job.ChildJobs[0].Output
    Stop-Job -Name "$name"

    write-host $joboutput
    write-host $job.ChildJobs[0].Error

    return $joboutput
}

END {}

}



### -----------------------------------------
### END
### -----------------------------------------