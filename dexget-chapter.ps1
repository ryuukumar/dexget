

$mkdirbuffer
$width = 1000
$lang = "en"
$savedir = "Manga"
$clouddir = "C:\users\adity\iCloudDrive\Manga"

function Remove-IllegalChars([string]$str) {
	$illegalCharsArr = [System.IO.Path]::GetInvalidFileNameChars()
	$illegalChars = [RegEx]::Escape(-join $illegalCharsArr)
	$ret = [regex]::Replace($str, "[${illegalChars}]", '_')
	$ret = $ret -replace "\[","_" -replace "\]","_" -replace "`'","_" -replace "`"","_"

	return $ret
}

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

. "$PSScriptRoot\ProgressBar.ps1"
. "$PSScriptRoot\ProgressBlip.ps1"

[string]$url=""
[bool]$cloudcopy=$false

if ($args[0]) {
	$url = $args[0]
} else {
	$url = Read-Host "Id"
}

$dlPolicySet = $false
$singleDl = $false
if ($args[1]) {
	if (-not ($args[1] -eq "Y" -or $args[1] -eq "y")) {
		$singleDl = $true
		$dlPolicySet = $true
	}
}

$manga = (Invoke-WebRequest "https://api.mangadex.org/chapter/${url}?includes[]=scanlation_group&includes[]=manga").content | ConvertFrom-Json

#$manga.data.relationships | ConvertTo-Json

$groups=@()
$mangaid=""
$mangatitle=""

foreach ($scg in $manga.data.relationships) {
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
		} elseif ($titlelist.jp) {
			$mangatitle = $titlelist.jp
		} else {
			$mangatitle = $mangaid
		}
		$mangatitle = Remove-IllegalChars ($mangatitle)
	}
}

write-host "Identified title $mangatitle"

if($mangatitle.length -gt 30) {
	# U+2026 -> ellipsis (three dots)
	$mangatitle = $mangatitle.substring(0, 20) + [char]0x2026
}

#$groups

$allchlink = "https://api.mangadex.org/manga/${mangaid}/aggregate?translatedLanguage[]=${lang}"

foreach ($grp in $groups) {
	$allchlink += "&groups[]=$grp"
}

#$allchlink

$allchapters = (Invoke-WebRequest $allchlink).content | ConvertFrom-Json

#$allchapters | ConvertTo-Json

$chapters = @()

$volcount = 1
$lastchp = 1
while ($allchapters.volumes.$volcount) {
	$chpcount = 0
	while ($allchapters.volumes.$volcount.chapters.$lastchp) {
		$chapters += $allchapters.volumes.$volcount.chapters.$lastchp
		$lastchp++
		$chpcount++
	}
	#Write-Host "Found $chpcount chapters in volume $volcount"
	$volcount++
}

if ($allchapters.volumes.none) {
	$chpcount = 0
	while ($allchapters.volumes.none.chapters.$lastchp) {
		$chapters += $allchapters.volumes.none.chapters.$lastchp
		$lastchp++
		$chpcount++
	}
	#Write-Host "Found $chpcount chapters without any volume"
	$volcount++
}

#$chapters | ConvertTo-Json

function get-chpindex {
	param (
		[ref]$chps,
		[string]$id
	)

	for ($i=0; $i -lt $chps.value.length; $i++) {
		if ($chps.value[$i].id -ne $id) {continue}
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


Write-Host "Scan results: Found $($chapters.length) chapters over $volcount volumes."

$chpindex = get-chpindex ([ref]$chapters) $url

Write-Host "Currently on chapter $($chapters[$chpindex].chapter)."

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
		get-chapter $url
		rename-item "$($url).pdf" "($($chpindex + 1)) ${mangatitle}.pdf" -Force
		if ($clchoice -eq "y" -or $clchoice -eq "Y") {
			Copy-Item -Path "($($chpindex + 1)) ${mangatitle}.pdf" "$clouddir\$mangadir"
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
		write-host "`n+-------------------+`n  Chapter $($i + 1) of $($chapters.length)`n+-------------------+"
		get-chapter $chapters[$i].id
		rename-item "$($chapters[$i].id).pdf" "($($i + 1)) ${mangatitle}.pdf" -Force
		if ($clchoice -eq "y" -or $clchoice -eq "Y") {
			Copy-Item -Path "($($i + 1)) ${mangatitle}.pdf" "$clouddir\$mangadir"
		}
	}

	write-host "`n+------------------------+`n  All downloads completed.`n+------------------------+"

	cd ".."
}

cd ..

exit