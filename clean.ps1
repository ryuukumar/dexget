

# relative to current directory
$savedir = "Manga"

$tbd = [System.Collections.ArrayList]@()

write-host -NoNewline "Scanning $(Get-Location)\$savedir... "
Get-ChildItem "$savedir" | ForEach-Object {
	if (((($_ -split ' ')[0]) -eq "$(get-location)\$savedir\(Manga)") -and (test-path $_ -PathType Container)) {
		$files = $(Get-ChildItem "$_")
		$filenos = [System.Collections.ArrayList]@()

		foreach ($file in $files.name) {
			[double]$chnum = (($file -split "\)")[0]) -replace '[^0-9.]',''
			$filenos.add($chnum) | out-null
		}
		
		$lastch = [double](($filenos | Measure-Object -Maximum).Maximum)
		$filenos.remove($lastch)
		$secondlastch = [double](($filenos | Measure-Object -Maximum).Maximum)
		$firstch = [double](($filenos | Measure-Object -Minimum).Minimum)

		#write-host "$_ : $lastch"

		$log = [PSCustomObject]@{
			keepnum = $lastch
			keeppath = ""
			del = [System.Collections.ArrayList]@()
			secondlast = $secondlastch
			first = $firstch
			files = $files.Name
			mangapath = [string]$_
		}

		foreach($file in $files.name) {
			[double]$chnum = (($file -split "\)")[0]) -replace '[^0-9.]',''
			if ($chnum -ne $lastch) {
				#write-host "`tSchedule $file for deletion."
				$log.del.add([PSCustomObject]@{
					number = $chnum
					path = "$_\$file"
				}) | out-null
			}
			else {
				$log.keeppath = "$_\$file"
			}
		}

		$tbd.add($log) | out-null
	}
}

write-host "done." -ForegroundColor Green

write-host -NoNewline "$($tbd.length.length) " -ForegroundColor Yellow
write-host "manga found."

$del = [System.Collections.ArrayList]@()
$keep = [System.Collections.ArrayList]@()

$tbd | ForEach-Object {
	$keep.add($_.keeppath) | out-null
	$_.del | ForEach-Object {
		$del.add($_.path) | out-null
	}
}

if ($del.length.length -eq 0) {
	write-host "There are no files to be deleted. Aborting."
	exit
}

write-host "After this operation, the following $($del.length.length) files will be " -NoNewline
write-host "permanently deleted" -ForegroundColor Red

$maxlen_of_filename = 0
$tbd | ForEach-Object {
	if (($_.mangapath -split "\\")[-1].length -gt $maxlen_of_filename) {
		$maxlen_of_filename = ($_.mangapath -split "\\")[-1].length
	}
}

$tbd | ForEach-Object {
	if ($_.del.length.length -ge 1) {
		write-host "  " -NoNewline
		write-host "$(($_.mangapath -split "\\")[-1])" -NoNewline
		for ($i=0; $i -lt ($maxlen_of_filename-($_.mangapath -split "\\")[-1].length)+2; $i++) { write-host " " -NoNewline }
		write-host " Chapters $($_.first) - $($_.secondlast)" -NoNewline -ForegroundColor Red
		write-host "    [$($_.del.length.length) files]" -ForegroundColor Yellow
	}
}

write-host "`nThe following $($keep.length.length) files will be " -NoNewline
write-host "kept" -ForegroundColor Green

$tbd | ForEach-Object {
	write-host "  " -NoNewline
	write-host "$(($_.mangapath -split "\\")[-1])" -NoNewline
	for ($i=0; $i -lt ($maxlen_of_filename-($_.mangapath -split "\\")[-1].length)+2; $i++) { write-host " " -NoNewline }
	write-host " Chapter $($_.keepnum)" -ForegroundColor Green
}

write-host "`nThis process is " -NoNewline
write-host "irreversible" -NoNewline -ForegroundColor Red
write-host ", and there will be " -NoNewline
write-host "no way to restore deleted files" -NoNewline -ForegroundColor Red
write-host " after this operation."
$continue = Read-Host "Do you want to continue? [Y/n]"

if ($continue -eq "y" -or $continue -eq "Y") {
	$del | ForEach-Object {
		if (Test-Path "$_") {
			if ($keep.Contains($_)) {
				write-host "Prevented $_ from being deleted."
			} else {
				remove-item "$_"
			}
		} else {
			write-host "$_ is fake."
		}
	}
	$keep | ForEach-Object {
		if (-not (Test-Path "$_") -and $_ -ne "") {
			write-host "ERROR: " -NoNewline -ForegroundColor Red
			write-host "File $_ is missing, even though it was scheduled for keeping."
		}
	}

	write-host "Deleted $($del.length.length) files."
	write-host "$($keep.length.length) files scheduled for keeping have been verified to exist."
	write-host "Operation successful. Exiting." -ForegroundColor Green
}
else {
	write-host "Aborting."
}