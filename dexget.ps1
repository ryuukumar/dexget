

#
#	DEXGET.PS1
#	A short script to download manga from MangaDex and save it locally for reading on-the-go
#	Author: @ryuukumar (https://github.com/ryuukumar)
#


$VERSION = '1.3 β'





#---------------------------------------#
#  FUNCTIONS                            #
#---------------------------------------#


# This function takes a string as input, removes any illegal characters from it (characters not allowed in a filename), and returns the cleaned string.
function Remove-IllegalChars([string]$str) {
	$illegalCharsArr = [System.IO.Path]::GetInvalidFileNameChars()
	$illegalChars = [RegEx]::Escape(-join $illegalCharsArr)
	$ret = [regex]::Replace($str, "[${illegalChars}]", '_')
	$ret = $ret -replace "\[","_" -replace "\]","_" -replace "`'","_" -replace "`"","_"

	return $ret
}

# This function takes a URL as input, sends an HTTP request to it, and returns the content length (file size) of the requested resource.
function Get-WebSize ([string]$url) {
	$HttpWebResponse = $null
	$HttpWebRequest = [System.Net.HttpWebRequest]::Create($url)
	try {
		$HttpWebResponse = $HttpWebRequest.GetResponse()
		$HttpWebResponse.close()
		return $HttpWebResponse.ContentLength
	}
	catch {
		$_ | ConvertTo-Json
	}
}

# This function takes a filename as input and returns the file extension by extracting it from the input filename.
function Get-FileType([string]$filename) {
	return $filename.Split('.')[-1]
}

# This function takes an integer file size (in bytes) as input and returns a formatted string with the file size in bytes, kilobytes, or megabytes, depending on the size.
function Format-Filesize([int]$length) {
	if ($length -lt 1000) {
		return "$length bytes"
	}
	elseif ($length -lt 1MB) {
		return "{0:N0}KB" -f ($length/1KB)
	}
	else {
		return "{0:N2}MB" -f ($length/1MB)
	}
}

# This function takes two integers as input (target and maxval), and returns the target number as a string, left-padded with zeroes to match the number of digits in maxval.
function Add-Zeroes {
	param (
		[int]$target,
		[int]$maxval
	)
	return $target.ToString().PadLeft(([string]$maxval).Length, '0')
}

function Write-Box {
    param (
        [string]$text,
        [bool]$center=$false,
		[System.ConsoleColor]$fgcolor=[System.ConsoleColor]"White"
	)
    
    $lines = $text -split "`n"
    $maxWidth = ($lines | Measure-Object -Property Length -Maximum).Maximum

    Write-Host ("+" + "-" * $maxWidth + "--" + "+") -ForegroundColor $fgcolor

    foreach ($line in $lines) {
        if ($center) {
            $leftPadding = [math]::Floor(($maxWidth - $line.Length) / 2)
            $rightPadding = $maxWidth - $line.Length - $leftPadding
            Write-Host ("  " + " " * $leftPadding + $line + " " * $rightPadding + " ") -ForegroundColor $fgcolor
        } else {
            Write-Host ("  " + $line.PadRight($maxWidth) + " ") -ForegroundColor $fgcolor
        }
    }

    Write-Host ("+" + "-" * $maxWidth + "--" + "+")  -ForegroundColor $fgcolor
}

function Move-Up {
	$pos = $host.UI.RawUI.CursorPosition
	$pos.Y--
	$host.UI.RawUI.CursorPosition = $pos
}

function Get-ChpIndex {
	param (
		[ref]$chps,
		[string]$chpnum
	)

	for ($i=0; $i -lt $chps.value.length; $i++) {
		if ($chps.value[$i].attributes.chapter -ne $chpnum) {continue}
		return $i
	}

	return -1
}





#---------------------------------------#
#  INCLUDES                             #
#---------------------------------------#


. "$PSScriptRoot/scripts/debug.ps1"
. "$PSScriptRoot/scripts/imgdl.ps1"
. "$PSScriptRoot/scripts/imgconv.ps1"
. "$PSScriptRoot/scripts/pdfconv.ps1"
. "$PSScriptRoot/scripts/progdisp.ps1"
. "$PSScriptRoot/scripts/defaults.ps1"





#---------------------------------------#
#  ENTRY POINT                          #
#---------------------------------------#


#  0. ASSERT POWERSHELL 7

if ($PSVersionTable.PSVersion.Major -lt 7) {
	write-box "`nFATAL ERROR!!!`n`nThis script is running on Powershell $($PSVersionTable.PSVersion.Major).`nDexGet requires Powershell 7 or higher to run!`nPlease install Powershell 7 and then run this script.`n" -fgcolor Red -center $true
	exit
}


#  1. LOAD SETTINGS

[hashtable]$settings = @{}
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

$debugmode = $settings.'general'.'debug-mode'

if ($settings.'general'.'debug-mode') {
	write-dbg "DexGet is running in Debug mode. It will be very verbose!`n`t`tYou can disable this by changing General > Debug Mode setting." -level "info"
}

if ($settings.'performance'.'pdf-method' -ne "magick" -and
	$settings.'performance'.'pdf-method' -ne "pypdf") {
	write-dbg "Invalid setting for Performance > PDF Method: $($settings.'performance'.'pdf-method')`nThe only accepted settings are 'magick' and 'pypdf'.`nSwitching to default." -level "error"
	$settings.'performance'.'pdf-method' = $defsettings.'performance'.'pdf-method'
}


#  1.1. UPDATE

if ($settings.'general'.'update-on-launch' -eq $true) {
	write-dbg "Update on launch is set to enabled. If there is an updated version, it will run at the next run of DexGet." -level "info"
	git pull
}


#  2. GET ID AND PARSE ARGUMENTS

[string]$inputstr=""

if ($args[0]) {
	$inputstr = $args[0]
} else {
	$inputstr = Read-Host "Enter MangaDex title ID"
}

$url = ([regex]::Matches($inputstr, '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'))[0]

$argsettings = [PSCustomObject]@{
	continue = $false
	cloud = $false
	all = $false
	banner = $true
}

$i=0
while ($true) {
	if ($args[$i]) {
		if ($args[$i] -eq "--continue" -or $args[$i] -eq "-c") {
			$argsettings.continue = $true
		}
		if ($args[$i] -eq "--cloud" -or $args[$i] -eq "-C") {
			if ($settings.'general'.'enable-cloud-saving' -eq $false) {
				write-dbg "--cloud was passed but cloud saving is disabled in the preferences. The argument will be ignored." -level "warning"
			} else {
				$argsettings.cloud = $true
			}
		}
		if ($args[$i] -eq "--all" -or $args[$i] -eq "-a") {
			$argsettings.all = $true
		}
		if ($args[$i] -eq "--no-banner") {
			$argsettings.banner = $false
		}
	}
	else { break }
	$i++
}

if ($argsettings.banner -eq $true) {
	Write-Host ""
	Write-Box "DexGet v$VERSION`n@ryuukumar on GitHub`nhttps://github.com/ryuukumar/dexget" -center $true
	Write-Host ""
}


#  3. DOWNLOAD URL

# Long term:
# The permitted "limit" per request is 500 chapters. For anything beyond that, it is possible to use the
# "offset" parameter to get the chapters after 500 (by index). I could probably count on two hands how many
# manga (I would bother reading) have more than 500 chapters though.

Write-Host "Looking though URL...`r" -NoNewline

try {
	$client = New-Object System.Net.WebClient
	$client.Headers.add('Referer', 'https://mangadex.org/')
	$client.Headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0')
	$manga = $client.DownloadString("https://api.mangadex.org/manga/${url}/feed?translatedLanguage[]=$($settings.'general'.'manga-language')&includes[]=scanlation_group&includes[]=user&order[volume]=asc&order[chapter]=asc&includes[]=manga&limit=500") | ConvertFrom-Json
}
catch {
	write-host "`nFATAL ERROR!`n" -ForegroundColor red
	write-host "Something went wrong while getting the manga metadata. You can try the following:`n - Verify that this is the correct URL:`n`n`thttps://mangadex.org/title/${url}/`n`n - Check your internet connection.`n - Make sure there is no firewall blocking PowerShell.`n - If this doesn't fix it, report a bug."
	write-host "`nTechnical details:`n$_" -ForegroundColor Yellow
	exit
}


#  4. SCOUR MANGA FOR DATA

$groups=@()
$mangaid=""
$mangatitle=""

foreach ($scg in $manga.data[0].relationships) {
	if ($scg.type -eq "scanlation_group") { 
		$groups += $scg.id
	}
	# TODO: look into $scg.attributes.altTitles to give language-specific titles to manga
	if ($scg.type -eq "manga") {
		$mangaid = $scg.id
		[string]$titles = $scg.attributes.title
		$titles = $titles.substring(2, $titles.length - 3)
		$titles = $titles -replace ';',"`n"
		$titlelist = $titles | ConvertFrom-StringData
		if ($titlelist.en) {
			$mangatitle = $titlelist.en
		} elseif ($titlelist.ja) {
			$mangatitle = $titlelist.ja
		} else {
			$mangatitle = $mangaid
		}
		$mangatitle = Remove-IllegalChars ($mangatitle)
	}
}

write-host "Identified title: " -NoNewline
write-host "$mangatitle" -ForegroundColor Yellow

if($mangatitle.length -gt 30) {
	# U+2026 -> ellipsis (three dots)
	$mangatitle = $mangatitle.substring(0, 20) + [char]0x2026
}

$chapters = @()
[double]$avglen = 0

foreach ($ch in $manga.data) {
	if ($ch.type -ne "chapter") {
		continue
	}
	if ($chapters.attributes.chapter -contains $ch.attributes.chapter) {
		continue
	}
	$chapters += $ch
	$avglen += $ch.attributes.pages
}

$avglen = $avglen / $chapters.length

Write-Host "Scan results:"
Write-Host " - Found $($chapters.length) chapters." -ForegroundColor Green
Write-Host " - About $(`"{0:n1}`" -f $avglen) pages per chapter." -ForegroundColor Green
Write-Host " - First chapter number: $($chapters[0].attributes.chapter)" -ForegroundColor Green

$chpindex = 0
$chpnum = 0


#  5. GET USER INPUT ON WHAT TO DO

if (test-path "$($settings.'general'.'manga-save-directory')/(Manga) ${mangatitle}") {
	Write-Host "Found a previous save of the manga in the save directory." -ForegroundColor Yellow

	$files = $(Get-ChildItem "$($settings.'general'.'manga-save-directory')/(Manga) ${mangatitle}")
	$filenos = @()

	foreach ($file in $files.name) {
		[double]$chnum = (($file -split "\)")[0]) -replace '[^0-9.]',''
		$filenos += $chnum
	}
	
	$lastch = [double](($filenos | Measure-Object -Maximum).Maximum)
	$chindex = get-chpindex ([ref]$chapters) $lastch

	if ($chindex -eq $chapters.length - 1) {
		$redown = ($argsettings.continue `
						? 'n' `
						: (Read-Host "The offline copy of the manga is up to date. Would you still like to proceed? [Y/n]"))
		if ($redown -eq 'Y' -or $redown -eq 'y') {
			$chpnum = read-host "Start from chapter"
			$chpindex = get-chpindex ([ref]$chapters) $chpnum
		}
		else {
			Write-Host "Nothing to download. Exiting."
			exit
		}
	}

	else {
		$cont = ($argsettings.continue `
					? 'y' `
					: (Read-Host "This manga was previously downloaded till chapter $lastch. Do you wish to continue? [Y/n]"))
		if ($cont -eq 'y' -or $cont -eq 'Y') {
			$chpindex = $chindex+1
			$chpnum = $lastch
		} else {
			$chpnum = read-host "Start from chapter"
			$chpindex = get-chpindex ([ref]$chapters) $chpnum
		}
	}
}

else {
	$chpnum = read-host "Start from chapter"
	$chpindex = get-chpindex ([ref]$chapters) $chpnum
}

if ($chpindex -eq -1) {
	write-host "ERROR: " -NoNewline -ForegroundColor Red
	Write-Host "No chapter found with chapter number $chpnum!"
	exit
}


#  6. FUNCTION DEFINITION FOR GETTING THE CHAPTER

$client = New-Object System.Net.WebClient
$chapterqueue = [System.Collections.ArrayList]@()

function queue-chapter {
	param (
		[string]$id,
		[string]$title,
		[string]$outdir,
		[string]$cloudd
	)

	$client.Headers.add('Referer', 'https://mangadex.org/')
	$client.Headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0')
	$json = $client.DownloadString("https://api.mangadex.org/at-home/server/${id}?forcePort443=false") | ConvertFrom-Json

	$imglist = $json.chapter.data
	$hash = $json.chapter.hash
	$imglen = $imglist.length

	$newchap = [PSCustomObject]@{
		images = $imglist
		id = $id
		outdir = $outdir
		title = $title
		dlcomp = [System.Collections.ArrayList]@()
		convcomp = 0
		total = $imglen
		hash = $hash
		toconv = [System.Collections.ArrayList]@()
		pdfmade = $false
		clouddir = $cloudd
	}

	$chapterqueue.add($newchap) | Out-Null
}

function download-queue {
	write-host "`n"
	if ($settings.'general'.'debug-mode' -eq $false) {
		$imgdljob = Start-ThreadJob -ScriptBlock $imgdl -ArgumentList ([ref]$chapterqueue)
		$imgconvjob = Start-ThreadJob -ScriptBlock $imgconv -ArgumentList ([ref]$chapterqueue)
		$pdfconvjob = Start-ThreadJob -ScriptBlock $pdfconv -ArgumentList ([ref]$chapterqueue)
		& $progdisp ([ref]$chapterqueue)
	} else {
		Write-Box "Starting download process."
		& $imgdl ([ref]$chapterqueue)

		Write-Box "Downloads complete.`nStarting conversions."
		& $imgconv ([ref]$chapterqueue)
		
		Write-Box "Conversions complete.`nStarting PDF generation."
		& $pdfconv ([ref]$chapterqueue)
	}
	write-host ""
}


#  7. GET THE ACTUAL CHAPTER

try {
	Write-Host ""

	if (($chpindex) -lt $chapters.length) {
		$choice = ($argsettings.all `
			? 'y' `
			: (Read-Host "There are $($chapters.length - 1 - $chpindex) more chapters after the given ID. Would you like to download all of them? [Y/n/s]"))

		$clchoice
		if ($settings.'general'.'enable-cloud-saving' -eq $true) {
			$clchoice = ($argsettings.cloud ? 'y' `
				: (Read-Host "Do you want to save a copy of this download to the cloud? [Y/n]"))
		} else {
			$clchoice = 'n'
		}
		

		if (-not ($choice -eq "Y" -or $choice -eq "y" -or $choice -eq "S" -or $choice -eq "s")) {
			if ($settings.'general'.'debug-mode' -eq $true) {
				write-host "[INFO]`tOutput directory for manga set to $((resolve-path $settings.'general'.'manga-save-directory').Path)." -ForegroundColor Blue
			}

			queue-chapter $chapters[$chpindex].id `
				-title "($($chapters[$chpindex].attributes.chapter)) ${mangatitle}.pdf" `
				-outdir "$($settings.'general'.'manga-save-directory')/$($chapters[$chpindex].id)" `
				-cloudd (($clchoice -eq 'y' -or $clchoice -eq 'Y') ? "$($settings.'general'.'cloud-save-directory')" : 0)			
			write-host ""
			Write-Box "Starting 1 download task." -fgcolor Blue
			write-host ""
	
			download-queue
		}

		else {
			if ($choice -eq "S" -or $choice -eq "s") {
				[int]$last = Read-Host "Number of chapters to download"
				$last += $chpindex
				if ($last -ge $chapters.length) {
					$last = $chapters.length
				}
				write-Host "Downloading till chapter $last."
			} else { [int]$last = $chapters.length }

			$mangadir = "(Manga) ${mangatitle}"
			if (!(Test-Path "$($settings.'general'.'manga-save-directory')/$mangadir")) {
				mkdir "$((resolve-path "$($settings.'general'.'manga-save-directory')").Path)/$mangadir" | out-null
			}
			
			if ($settings.'general'.'debug-mode' -eq $true) {
				write-dbg "Output directory for manga set to $((resolve-path "$($settings.'general'.'manga-save-directory')/$mangadir").Path)." -level "info"
			}

			write-host ""
			Write-Box "Queueing $($last - $chpindex) download tasks." -fgcolor Blue
			write-host ""

			if ($clchoice -eq "y" -or $clchoice -eq "Y") {
				if (!(Test-Path "$($settings.'general'.'cloud-save-directory')/$mangadir")) {
					mkdir "$($settings.'general'.'cloud-save-directory')/$mangadir" | out-null
				}
			}
			
			for ($i=$chpindex; $i -lt $last; $i++) {
				queue-chapter $chapters[$i].id `
					-title "($($chapters[$i].attributes.chapter)) ${mangatitle}.pdf" `
					-outdir "$($settings.'general'.'manga-save-directory')/${mangadir}/$($chapters[$i].id)" `
					-cloudd (($clchoice -eq 'y' -or $clchoice -eq 'Y') ? "$($settings.'general'.'cloud-save-directory')/$mangadir" : 0)
				if (($clchoice -eq 'y' -or $clchoice -eq 'Y') -and -not (test-path "$($settings.'general'.'cloud-save-directory')/$mangadir"))
				{ mkdir "$($settings.'general'.'cloud-save-directory')/$mangadir" | out-null }

				if ($settings.'general'.'debug-mode' -eq $false) {
					write-host "Queued chapter $($chapters[$i].attributes.chapter) ($($i-$chpindex+1))    `r" -NoNewline
				} else {
					write-dbg "Queued chapter count $($i-$chpindex+1) from https://mangadex.org/chapter/$($chapters[$i].id)" -level "debug"
				}

				if (((($i-$chpindex+1) / 20) -eq [int](($i-$chpindex+1) / 20)) -and $i -ne $chpindex) {
					$startdate = (Get-Date)
					download-queue
					$chapterqueue = [System.Collections.ArrayList]@()
					$Enddate = (Get-Date)
					$diff = New-TimeSpan -Start $startdate -End $Enddate 
					if ($diff.totalseconds -lt 60) {
						[int]$secs = (60-$diff.totalseconds)
						for ($j = $secs; $j -gt 0; $j--) {
							write-host "Pausing for $secs seconds to avoid 429 error. ($j left) `r" -NoNewline
							start-sleep -seconds 1
						}
						write-host $(" " * ([int]$($Host.UI.RawUI.WindowSize.Width))) -NoNewline
						write-host "`r" -NoNewline
					}
				}
			}
			if ($chapterqueue.length.length -ge 1) {
				download-queue
			}
			Write-Host ""
		}

		Write-Box "All download tasks completed." -fgcolor Green
	}
}
catch {
	Write-Host "`n`n!! Something bad just happened: " -ForegroundColor Yellow
	Write-Box "$_" -fgcolor Red
}

finally {
	Write-Host "`nExiting. $_"
}





#---------------------------------------#
#  EXIT                                 #
#---------------------------------------#


$settings | ConvertTo-Json | Out-File 'preferences.json'

exit