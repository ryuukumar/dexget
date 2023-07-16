

#
#	DEXGET.PS1
#	A short script to download manga from MangaDex and save it locally for reading on-the-go
#	Author: @ryuukumar (https://github.com/ryuukumar)
#


$VERSION = '1.2'





#---------------------------------------#
#  PREFERENCES                          #
#---------------------------------------#


$width = 1000
$lang = "en"
$savedir = "Manga"
$clouddir = "C:\users\adity\iCloudDrive\Manga"
$maxConcurrentJobs = 25





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


. "$PSScriptRoot\ProgressBar.ps1"
. "$PSScriptRoot\ProgressBlip.ps1"
. "$PSScriptRoot\scripts\imgdl.ps1"





#---------------------------------------#
#  ENTRY POINT                          #
#---------------------------------------#


#  0. GET ID

Write-Host ""
Write-Box "DexGet v$VERSION`n@ryuukumar on GitHub`nhttps://github.com/ryuukumar/dexget" -center $true
Write-Host ""

[string]$url=""
[bool]$cloudcopy=$false

if ($args[0]) {
	$url = $args[0]
} else {
	$url = Read-Host "Enter MangaDex title ID"
}

$dlPolicySet = $false
$singleDl = $false
if ($args[1]) {
	if (-not ($args[1] -eq "Y" -or $args[1] -eq "y")) {
		$singleDl = $true
		$dlPolicySet = $true
	}
}


#  1. DOWNLOAD URL

# Long term:
# The permitted "limit" per request is 500 chapters. For anything beyond that, it is possible to use the
# "offset" parameter to get the chapters after 500 (by index). I could probably count on two hands how many
# manga (I would bother reading) have more than 500 chapters though.

Write-Host "Looking though URL...`r" -NoNewline

try {
	$client = New-Object System.Net.WebClient
	$manga = $client.DownloadString("https://api.mangadex.org/manga/${url}/feed?translatedLanguage[]=${lang}&includes[]=scanlation_group&includes[]=user&order[volume]=asc&order[chapter]=asc&includes[]=manga&limit=500") | ConvertFrom-Json
}
catch {
	write-host "`nFATAL ERROR!`n" -ForegroundColor red
	Write-Host "Something went wrong while getting the manga metadata. You can try the following:`n - Verify that this is the correct URL:`n`n`thttps://mangadex.org/title/${url}/`n`n - Check your internet connection.`n - Make sure there is no firewall blocking PowerShell.`n - If this doesn't fix it, report a bug."
	exit
}


#  2. SCOUR MANGA FOR DATA

$groups=@()
$mangaid=""
$mangatitle=""

foreach ($scg in $manga.data[0].relationships) {
	if ($scg.type -eq "scanlation_group") { 
		$groups += $scg.id
	}
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

foreach ($ch in $manga.data) {
	if ($ch.type -ne "chapter") {
		continue
	}
	if ($chapters.attributes.chapter -contains $ch.attributes.chapter) {
		continue
	}
	$chapters += $ch
}

Write-Host "Scan results:"
Write-Host " - Found $($chapters.length) chapters." -ForegroundColor Green
Write-Host " - First chapter number: $($chapters[0].attributes.chapter)" -ForegroundColor Green

$chpindex = 0
$chpnum = 0


#  3. GET USER INPUT ON WHAT TO DO

if (test-path "$savedir\(Manga) ${mangatitle}") {
	Write-Host "Found a previous save of the manga in the save directory." -ForegroundColor Yellow

	$files = $(Get-ChildItem "$savedir\(Manga) ${mangatitle}")
	$filenos = @()

	foreach ($file in $files) {
		[double]$chnum = (($file -split "\)")[0]) -replace '[^0-9.]',''
		$filenos += $chnum
	}
	
	$lastch = [double](($filenos | Measure-Object -Maximum).Maximum)
	$chindex = get-chpindex ([ref]$chapters) $lastch

	if ($chindex -eq $chapters.length - 1) {
		$redown = Read-Host "The offline copy of the manga is up to date. Would you still like to proceed? [Y/n]"
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
		$cont = Read-Host "This manga was previously downloaded till chapter $lastch. Do you wish to continue? [Y/n]"
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
}


#  4. FUNCTION DEFINITION FOR GETTING THE CHAPTER

$client = New-Object System.Net.WebClient
$chapterqueue = [System.Collections.ArrayList]@()

function queue-chapter {
	param (
		[string]$id,
		[string]$title,
		[string]$outdir
	)

	$json = $client.DownloadString("https://api.mangadex.org/at-home/server/${id}?forcePort443=false") | ConvertFrom-Json

	$imglist = $json.chapter.data
	$hash = $json.chapter.hash
	$imglen = $imglist.length

	$newchap = [PSCustomObject]@{
		images = $imglist
		id = $id
		outdir = $outdir
		title = $title
		completed = 0
		total = $imglen
		hash = $hash
	}

	$chapterqueue.add($newchap) | Out-Null
}


#  5. GET THE ACTUAL CHAPTER

$originaldir = Get-Location

try {
	Write-Host ""

	Set-Location $savedir

	if (($chpindex) -lt $chapters.length) {
		if ($dlPolicySet) {
			if ($singleDl) { $choice = "n" }
			else { $choice = "y" }
		} else {
			$choice = Read-Host "There are $($chapters.length - 1 - $chpindex) more chapters after the given ID. Would you like to download all of them? [Y/n/s]"
		}

		if (-not $cloudcopy) { $clchoice = Read-Host "Do you want to save a copy of this download to the cloud? [Y/n]" }

		if (-not ($choice -eq "Y" -or $choice -eq "y" -or $choice -eq "S" -or $choice -eq "s")) { 
			Write-Host "$chpindex`n$($chapters[$chpindex].id)`n$($chapters[$chpindex].attributes.chapter)"
			queue-chapter $chapters[$chpindex].id `
				-title "($($chapters[$chpindex].attributes.chapter)) ${mangatitle}.pdf" `
				-outdir "$(Get-Location)\$($chapters[$chpindex].id)"
			if ($clchoice -eq "y" -or $clchoice -eq "Y") { Copy-Item -Path "($($chapters[$chpindex].attributes.chapter)) ${mangatitle}.pdf" "$clouddir\$mangadir" }
			#exit
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
			if (!(Test-Path $mangadir)) { mkdir $mangadir | out-null }
			Set-Location "$(Get-Location)\${mangadir}"

			write-host ""
			Write-Box "Starting $($last - $chpindex) download tasks." -fgcolor Blue
			write-host ""

			if ($clchoice -eq "y" -or $clchoice -eq "Y") {
				if (!(Test-Path "$clouddir\$mangadir")) {
					mkdir "$clouddir\$mangadir" | out-null
				}
			}
			
			for ($i=$chpindex; $i -lt $last; $i++) {
				queue-chapter $chapters[$i].id -title "($($chapters[$i].attributes.chapter)) ${mangatitle}.pdf" -outdir "$(Get-Location)\$($chapters[$i].id)"
				if ($clchoice -eq "y" -or $clchoice -eq "Y") {
					Copy-Item -Path "($($chapters[$i].attributes.chapter)) ${mangatitle}.pdf" "$clouddir\$mangadir"
				}
			}
		}

		foreach ($chapter in $chapterqueue) {
			$outstr = "`nChapter queued for download`n"
			$outstr += "- Title: $($chapter.title)`n"
			$outstr += "- Id: $($chapter.id)`n"
			$outstr += "- Outdir: $($chapter.outdir)`n"
			$outstr += "- Completion: $($chapter.completed)/$($chapter.total)`n`n"
			$outstr += "List of image URLs:`n"
			foreach ($ur in $chapter.images) { $outstr += "$ur`n" }
			Write-box $outstr -fgcolor Cyan
			Write-Host ""
		}

		& $imgdl ([ref]$chapterqueue) | Out-Null

		foreach ($chapter in $chapterqueue) {
			$outstr = "`nChapter queued for download`n"
			$outstr += "- Title: $($chapter.title)`n"
			$outstr += "- Id: $($chapter.id)`n"
			$outstr += "- Outdir: $($chapter.outdir)`n"
			$outstr += "- Completion: $($chapter.completed)/$($chapter.total)`n`n"
			$outstr += "List of image URLs:`n"
			foreach ($ur in $chapter.images) { $outstr += "$ur`n" }
			Write-box $outstr -fgcolor Cyan
			Write-Host ""
		}

		Set-Location ".."
	}
}
catch {
	Write-Host "`n`n!! Something bad just happened: " -ForegroundColor Yellow
	Write-Box "$_" -fgcolor Red
}

finally {
	Set-Location $originaldir
	Write-Host "`nDownloads complete. $_"

	#exit
}





#---------------------------------------#
#  EXIT                                 #
#---------------------------------------#


Set-Location $originaldir

exit