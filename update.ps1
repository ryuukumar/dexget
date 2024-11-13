

#
#	UPDATE.PS1
#	Quick script to update all the manga listed in updates.txt
#	Author: @ryuukumar (https://github.com/ryuukumar)
#





#---------------------------------------#
#  FUNCTIONS                            #
#---------------------------------------#


. "$PSScriptRoot/scripts/functions.ps1"
. "$PSScriptRoot/scripts/defaults.ps1"
. "$PSScriptRoot/scripts/debug.ps1"

function Validate-MangaDexURL {
    param (
        [string]$inputString
    )

    # Define the regular expression pattern to match the required format
    # UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    $pattern = 'mangadex\.org/title/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    return $inputString -match $pattern
}





#---------------------------------------#
#  ENTRY POINT                          #
#---------------------------------------#


$settings = Load-Settings

if (-not(Test-Path "$(Get-Location)/updates.txt")) {
    write-dbg "updates.txt was not found. Please create one with the list of manga you want downloaded." -level "error"
    exit
}

$file = Get-Content "$(Get-Location)/updates.txt"

write-host "Reading updates.txt contents..." -NoNewline

$i = 0
$validlinks = @()
foreach ($line in $file) {
    if (Validate-MangaDexURL $line) {
        $validlinks += $line
        $i += 1
        write-host "`rReading updates.txt contents... found $i link(s)." -NoNewline
    }
}

write-host "`nChecking remote for latest releases... 0 of $($validlinks.length)" -NoNewline

$i = 0
$updatedmanga = @()
foreach ($line in $validlinks) {
    $result = $(./dexget.ps1 $line --scanonly -j --check-latest --no-banner)
    $mangadetails = $result[1]
    $latestch = $result[2]

    if ($null -ne $mangadetails) { $mangadetails = $mangadetails | ConvertFrom-Json }
    if ($null -ne $latestch) { $latestch = $latestch | ConvertFrom-Json }
    if ($null -eq $mangadetails -or $null -eq $latestch) { continue }

    $mangatitle = get-title $mangadetails.attributes.title
    if (test-path "$($settings.'general'.'manga-save-directory')/(Manga) ${mangatitle}") {
        $latestch_local = Get-LatestCh "$($settings.'general'.'manga-save-directory')/(Manga) ${mangatitle}"
        if ($latestch.attributes.chapter -ne $latestch_local) { $updatedmanga += $line }
    } else { $updatedmanga += $line }
    $i += 1
    write-host "`rChecking remote for latest releases... $i of $($validlinks.length)" -NoNewline
}

write-host ""
write-box  "Found $($updatedmanga.length) manga to try updating." -fgcolor yellow

$i = 1
foreach ($line in $updatedmanga) {
    write-host "$i of $($updatedmanga.length)" -ForegroundColor red
    ./dexget.ps1 $line -c -a -C --no-banner     # leap of faith
    write-host ""
    $i++
}

write-box "Updated all manga." -fgcolor green





#---------------------------------------#
#  EXIT                                 #
#---------------------------------------#

