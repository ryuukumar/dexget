

$mkdirbuffer
$width = 1000
$lang = "en"
$savedir = "Manga"
$clouddir = "C:\users\adity\iCloudDrive\Manga"



# This function takes a string as input, removes any illegal characters from it (characters not allowed in a filename), and returns the cleaned string.
function Remove-IllegalChars([string]$str) {
	$illegalCharsArr = [System.IO.Path]::GetInvalidFileNameChars()
	$illegalChars = [RegEx]::Escape(-join $illegalCharsArr)
	$ret = [regex]::Replace($str, "[${illegalChars}]", '_')
	$ret = $ret -replace "\[","_" -replace "\]","_" -replace "`'","_" -replace "`"","_"

	return $ret
}

# This function takes a URL as input, sends an HTTP request to it, and returns the content length (file size) of the requested resource.
function Web-FileSize ([string]$url) {
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
function Give-FileType([string]$filename) {
	$substrs = $filename -split '\.'
	return $substrs[$substrs.length - 1]
}

# This function takes an integer file size (in bytes) as input and returns a formatted string with the file size in bytes, kilobytes, or megabytes, depending on the size.
function Format-Filesize([int]$length) {
	if ($length -lt 1000) {
		return [string]::Format('{0:N0}',${length}) + " bytes"
	}
	else {
		if ($length / 1000 -lt 1000) {
			[string]${kbimg}=[string]::Format('{0:N0}',${length}/1024) + "KB"
			return ${kbimg}
		}
		else {
			[string]${mbytes}=[string]::Format('{0:N}',${length}/(1024*1024)) + "MB"
			return ${mbytes}
		}
	}
}

# This function takes two integers as input (target and maxval), and returns the target number as a string, left-padded with zeroes to match the number of digits in maxval.
function Add-Zeroes {
	param (
		[int]$target,
		[int]$maxval
	)
	$tgtlnt = ([string]$target).Length
	$maxlnt = ([string]$maxval).Length

	if ($tgtlnt -eq $maxlnt) {
		return ([string]$target)
	}

	[string]$ret=""
	for ($i=0; $i -lt ($maxlnt-$tgtlnt); $i++) {
		$ret += "0"
	}
	$ret += ([string]$target)

	return $ret
}

function Write-Box {
    param (
        [string]$text
    )

    # Split the text into lines
    $lines = $text -split "`n"

    # Determine the width of the box
    $maxWidth = ($lines | Measure-Object -Property Length -Maximum).Maximum

    # Print the top of the box
    Write-Host ("+" + "-" * $maxWidth + "--" + "+") 

    # Print each line of the box
    foreach ($line in $lines) {
        Write-Host ("  " + $line.PadRight($maxWidth)) 
    }

    # Print the bottom of the box
    Write-Host ("+" + "-" * $maxWidth + "--" + "+") 
}

. "$PSScriptRoot\ProgressBar.ps1"
. "$PSScriptRoot\ProgressBlip.ps1"

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

Write-Host "Looking though URL...`r" -NoNewline

# ----------------------------------------------------------------------------------------------------------
# Long term:
# The permitted "limit" per request is 500 chapters. For anything beyond that, it is possible to use the
# "offset" parameter to get the chapters after 500 (by index). I could probably count on two hands how many
# manga have more than 500 chapters though.
# ----------------------------------------------------------------------------------------------------------
try {
	$manga = (Invoke-WebRequest "https://api.mangadex.org/manga/${url}/feed?translatedLanguage[]=${lang}&includes[]=scanlation_group&includes[]=user&order[volume]=asc&order[chapter]=asc&includes[]=manga&limit=500").content | ConvertFrom-Json

}
catch {
	write-host "`nFATAL ERROR!`n" -ForegroundColor red
	Write-Host "Something went wrong getting the manga metadata. You can try the following:`n - Verify that this is the correct URL:`n`n`thttps://mangadex.org/title/${url}/`n`n - Check your internet connection.`n - Make sure there is no firewall blocking PowerShell.`n - If this doesn't fix it, report a bug."
	exit
}

#$manga.data[0].relationships | ConvertTo-Json

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

#$groups

#$allchlink = "https://api.mangadex.org/manga/${mangaid}/aggregate?translatedLanguage[]=${lang}"

#foreach ($grp in $groups) {
#	$allchlink += "&groups[]=$grp"
#}

#$allchlink

#$allchapters = (Invoke-WebRequest $allchlink).content | ConvertFrom-Json

#$allchapters | ConvertTo-Json

$chapters = @()

#$volcount = 1
#$lastchp = 1
foreach ($ch in $manga.data) {
	if ($ch.type -ne "chapter") {
		continue
	}
	if ($chapters.attributes.chapter -contains $ch.attributes.chapter) {
		continue
	}
	$chapters += $ch
}

#$chapters | ConvertTo-Json

function get-chpindex {
	param (
		[ref]$chps,
		[string]$chpnum
	)

	for ($i=0; $i -lt $chps.value.length; $i++) {
		if ($chps.value[$i].attributes.chapter -ne $chpnum) {continue}
		#$chps.value[$i]
		return $i
	}

	return -1
}

function get-nextchp {
	param (
		[ref]$chps,
		[string]$id
	)

	[int]$idx = get-chpindex $chps $id
	if ($idx -eq $chps.value.length) {
		return -1
	}
	return $chps.value[$idx+1].id
}


Write-Host -NoNewline "Scan results: "
Write-Host "Found $($chapters.length) chapters." -ForegroundColor Green

$chpnum = read-host "Start from chapter"
$chpindex = get-chpindex ([ref]$chapters) $chpnum

write-host "Chapter found at index $chpindex."

#$nextchp = get-nextchp ([ref]$chapters) $url

#if ($nextchp -ne -1) {
	#Write-Host "Next chapter is at ID ${nextchp}. You can access it at https://mangadex.org/chapter/${nextchp}/1"
#}

function get-chapter {
	param (
		[string]$id
	)

	$json = (Invoke-WebRequest "https://api.mangadex.org/at-home/server/${id}?forcePort443=false").content | ConvertFrom-Json

	#$json | ConvertTo-Json
	$baseUr = "https://uploads.mangadex.org"
	$hash = $json.chapter.hash

	$imglist = $json.chapter.data
	$images = $imglist.length
	write-host "Checking download size... " -NoNewline

	[int]$totalsize = 0

	foreach ($img in $imglist) {
		$filesize = Web-FileSize("$baseUr/data/$hash/$img")
		$totalsize += $filesize
	}

	$sizestr = Format-Filesize($totalsize)

	write-host "going to download $sizestr over $images images."

	$dlscript = {
		param($id, $baseUr, $hash, $images, $wd, $imglist)

		function Web-FileSize ([string]$url) {
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
		
		function Give-FileType([string]$filename) {
			$substrs = $filename -split '\.'
			return $substrs[$substrs.length - 1]
		}
		
		function Add-Zeroes {
			param (
				[int]$target,
				[int]$maxval
			)
			$tgtlnt = ([string]$target).Length
			$maxlnt = ([string]$maxval).Length
		
			if ($tgtlnt -eq $maxlnt) {
				return ([string]$target)
			}
		
			[string]$ret=""
			for ($i=0; $i -lt ($maxlnt-$tgtlnt); $i++) {
				$ret += "0"
			}
			$ret += ([string]$target)
		
			return $ret
		}

		if (-not (test-path "$wd\$id")) {
			$mkdirbuffer = mkdir "$wd\$id"
		}

		$i=0

		# Define the maximum number of concurrent downloads
		$maxConcurrentDownloads = 10

		# Create an array to hold the download jobs
		$downloadJobs = @()

		foreach ($img in $imglist) {
			$i++
			$filesize = Web-FileSize("$baseUr/data/$hash/$img")
			$filename = $(add-zeroes $i $images) + "." + $(Give-FileType $img)
			$url = "$baseUr/data/$hash/$img"
			$outputPath = "$wd/$id/$filename"

			write-error "Saving $url to $outputpath"
			
			# Define the script block for the download job
			$scriptBlock = {
				param($url, $outputPath, $filesize, $i, $images)
				
				(New-Object System.Net.WebClient).DownloadFile($url, $outputPath)
				
				Write-Host "`rDownloaded and saved $outputPath."
			}
			
			# Start the download job
			$job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $url, $outputPath, $filesize, $i, $images
			
			# Add the job to the download jobs array
			$downloadJobs += $job
			
			# If there are already the maximum number of download jobs running, wait for one to complete before starting another
			if ($downloadJobs.Count -eq $maxConcurrentDownloads) {
				$finishedJob = $downloadJobs | Wait-Job -Any
				$downloadJobs.Remove($finishedJob)
			}
		}

		# Wait for any remaining download jobs to complete
		$buffer = $downloadJobs | Wait-Job
	}

	progress-bar -scriptblock $dlscript -size $totalsize -dlfile "$(pwd)/$id" `
		-pretext "" -isdirectory $true -endwithnewline $true `
		-argumentlist @($id, $baseUr, $hash, $images, $(pwd), $imglist)

	Write-Host "Downloaded and saved $images images."

	#write-host "cd `"$(pwd)/$id`" ; foreach (`$img in `$(ls *.png).name) { magick convert `"`$img`" -quality 95 `"`$img.jpg`" ; remove-item `"`$img`" } ; cd `"..`""
	progress-blip -command "cd `"$(pwd)/$id`" ; foreach (`$img in `$(ls *.png).name) { magick convert `"`$img`" -quality 90 `"`$img.jpg`" ; remove-item `"`$img`" } ; cd `"..`"" `
		-pretext "Preparing images... " `
		-endwithnewline $false
	
	#write-host "magick `"$(pwd)/$id/*.jpg`" -density 720x `"$(pwd)/$id.pdf`" "
	progress-blip -command "magick `"$(pwd)/$id/*.jpg`" -density 80x -resize ${width}x -compress JPEG `"$(pwd)/$id.pdf`" " `
		-pretext "Converting to PDF... " `
		-endwithnewline $false
	
	progress-blip -command "cd `"$(pwd)`" ; remove-item $id -recurse" `
		-pretext "Clean up... " `
		-endwithnewline $false
	
}

cd $savedir

if (($chpindex) -lt $chapters.length) {
	if ($dlPolicySet) {
		if ($singleDl) {
			$choice = "n"
		} else {
			$choice = "y"
		}
	} else {
		$choice = Read-Host "There are $($chapters.length - 1 - $chpindex) more chapters after the given ID. Would you like to download all of them? [Y/n/s]"
	}

	if (-not $cloudcopy) {
		$clchoice = Read-Host "Do you want to save a copy of this download to the cloud? [Y/n]"
	}

	if (-not ($choice -eq "Y" -or $choice -eq "y" -or $choice -eq "S" -or $choice -eq "s")) { 
		get-chapter $chapters[$chpindex].id
		rename-item "$($chapters[$chpindex].id).pdf" "($($chapters[$chpindex].attributes.chapter)) ${mangatitle}.pdf" -Force
		if ($clchoice -eq "y" -or $clchoice -eq "Y") {
			Copy-Item -Path "($($chapters[$chpindex].attributes.chapter)) ${mangatitle}.pdf" "$clouddir\$mangadir"
		}

		exit
	}

	if ($choice -eq "S" -or $choice -eq "s") {
		[int]$last = Read-Host "Number of chapters to download"
		$last += $chpindex
		if ($last -ge $chapters.length) {
			$last = $chapters.length
		}
		write-Host "Downloading till chapter $last."
	} else {
		[int]$last = $chapters.length
	}

	$mangadir = "(Manga) ${mangatitle}"
	$mkdirbuffer = mkdir $mangadir
	cd "$(pwd)\${mangadir}"

	if ($clchoice -eq "y" -or $clchoice -eq "Y") {
		$mkdirbuffer = mkdir "$clouddir\$mangadir"
	}
	
	for ($i=$chpindex; $i -lt $last; $i++) {
		write-box "Chapter $($i + 1) of $($chapters.length)"
		get-chapter $chapters[$i].id
		rename-item "$($chapters[$i].id).pdf" "($($chapters[$i].attributes.chapter)) ${mangatitle}.pdf" -Force
		if ($clchoice -eq "y" -or $clchoice -eq "Y") {
			Copy-Item -Path "($($chapters[$i].attributes.chapter)) ${mangatitle}.pdf" "$clouddir\$mangadir"
		}
	}

	write-box "All downloads completed."

	cd ".."
}

cd ..

exit