#  3. DOWNLOAD URL

# Long term:
# The permitted "limit" per request is 500 chapters. For anything beyond that, it is possible to use the
# "offset" parameter to get the chapters after 500 (by index). I could probably count on two hands how many
# manga (I would bother reading) have more than 500 chapters though.


function Scan-Manga {
	param (
		$url,
		$language,
		[ref]$mangatitle,
		[ref]$chapters,
		[ref]$latest,
		[bool]$jsonmode
	)

	$manga
	$avglen = 0.0

	Write-Host "Looking though URL...`r" -NoNewline

	try {
		$client = New-Object System.Net.WebClient
		$client.Headers.add('Referer', 'https://mangadex.org/')
		$client.Headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0')
		$manga = $client.DownloadString("https://api.mangadex.org/manga/${url}/feed?translatedLanguage[]=${language}&includes[]=scanlation_group&includes[]=user&order[volume]=asc&order[chapter]=asc&includes[]=manga&limit=500") | ConvertFrom-Json
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
	$mangatitle.value=""
	$mangadetails = ""

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
				$mangatitle.value = $titlelist.en
			} elseif ($titlelist.ja) {
				$mangatitle.value = $titlelist.ja
			} else {
				$mangatitle.value = $mangaid
			}
			$mangatitle.value = Remove-IllegalChars ($mangatitle.value)
			if ($jsonmode) {
				$mangadetails = ($scg | ConvertTo-Json -Compress)
				write-host $mangadetails
			}
		}
	}

	if (-not $jsonmode) {
		write-host "Identified title: " -NoNewline
		write-host "$($mangatitle.value)" -ForegroundColor Yellow
	}

	if($mangatitle.value.length -gt 30) {
		# U+2026 -> ellipsis (three dots)
		$mangatitle.value = $mangatitle.value.substring(0, 20) + [char]0x2026
	}

	$chapters.value = @()
	[double]$avglen = 0

	foreach ($ch in $manga.data) {
		if ($ch.type -ne "chapter") {		# not a chapter
			continue
		}
		if ($null -ne $ch.attributes.externalUrl) {    # external chapter
			write-dbg "Found external link for chapter $($ch.attributes.chapter):`n`t`t$($ch.attributes.externalUrl)" -level "debug"
			continue
		}
		if ($chapters.attributes.chapter -contains $ch.attributes.chapter) {    # chapter already processed
			continue
		}

		$ch.PSObject.Properties.Remove('relationships')
		$chapters.value += $ch
		$avglen += $ch.attributes.pages
	}

	$avglen = $avglen / $chapters.value.length
	$latest.value = [double](($chapters.value.attributes.chapter | Measure-Object -Maximum).Maximum)

	$found_chapters = [System.Collections.ArrayList]@()
	foreach ($ch in $chapters.value) {
		$chint = [math]::floor([decimal]($ch.attributes.chapter))
		if ($found_chapters -notcontains $chint) {
			$found_chapters.add($chint) | Out-Null
		}
	}

	$missing_chapters = [System.Collections.ArrayList]@()
	for ([int]$i = [math]::floor([decimal]($chapters.value[0].attributes.chapter));
			$i -le $latest.value; $i+=1) {
		if ($found_chapters -notcontains $i) {
			$missing_chapters.add($i) | Out-Null
		}
	}	

	if ($jsonmode) {
		write-host ($chapters.value | ConvertTo-Json -Compress)
	} else {
		Write-Host "Scan results:"
		Write-Host " - Found $($chapters.value.length) chapters." -ForegroundColor Green
		Write-Host " - About $(`"{0:n1}`" -f $avglen) pages per chapter." -ForegroundColor Green
		Write-Host " - First chapter number: $($chapters.value[0].attributes.chapter)" -ForegroundColor Green
		Write-Host " - Latest available chapter: $($latest.value)" -ForegroundColor Green
		if ($missing_chapters.length.length -ne 0) {
			Write-Host " - Found missing chapters: $(ConvertTo-RangeString $missing_chapters)" -ForegroundColor Green
		}
	}
}