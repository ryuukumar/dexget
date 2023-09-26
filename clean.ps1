

# relative to current directory
$savedir = "Manga"
$sep = '/'
$fsep = '/'

if ($IsWindows) { $sep = '\' ; $fsep = '\\' }

function Format-Filesize([int]$length) {
	if ($length -lt 1000) {
		return "$length bytes"
	}
	elseif ($length -lt 1MB) {
		return "{0:N0} KB" -f ($length/1KB)
	}
	else {
		return "{0:N2} MB" -f ($length/1MB)
	}
}

$tbd = [System.Collections.ArrayList]@()
[System.Int128]$dellen = 0
[System.Int128]$keeplen = 0

write-host -NoNewline "Scanning $(Get-Location)$sep$savedir... "
Get-ChildItem "$savedir" | ForEach-Object {
	if (((($_ -split ' ')[0]) -eq "$(get-location)$sep$savedir$sep(Manga)") -and (test-path $_ -PathType Container)) {
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
			dellen = [System.Int128]0
			keeplen = [System.Int128]0
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
					path = "$_$sep$file"
				}) | out-null
				$dellen += [System.Int128]((Get-Item "$_$sep$file").Length)
				$log.dellen += [System.Int128]((Get-Item "$_$sep$file").Length)
			}
			else {
				$log.keeppath = "$_$sep$file"
				$keeplen += [System.Int128]((Get-Item "$_$sep$file").Length)
				$log.keeplen += [System.Int128]((Get-Item "$_$sep$file").Length)
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
		if ($_.path -ne "") {
			$del.add($_.path) | out-null
		}
	}
}

if ($del.length.length -eq 0) {
	write-host "There are no files to be deleted. Aborting."
	exit
}

$maxlen_of_filename = 0
$tbd | ForEach-Object {
	if (($_.mangapath -split "$fsep")[-1].length -gt $maxlen_of_filename) {
		$maxlen_of_filename = ($_.mangapath -split "$fsep")[-1].length
	}
}

write-host "`nAfter this operation, the following $($keep.length.length) files [$(Format-Filesize $keeplen)] will be " -NoNewline
write-host "kept" -ForegroundColor Green

$tbd | ForEach-Object {
	write-host "  " -NoNewline
	write-host "$(($_.mangapath -split "$fsep")[-1])" -NoNewline -ForegroundColor Cyan
	write-host (" " * (($maxlen_of_filename-($_.mangapath -split "$fsep")[-1].length)+2)) -NoNewline
	write-host " Chapter $($_.keepnum)" -ForegroundColor Green -NoNewline
	write-host (" " * (10-([string]($_.keepnum)).length)) -NoNewline
	write-host "$(Format-Filesize $_.keeplen)" -ForegroundColor Yellow
}

write-host "`nThe following $($del.length.length) files [$(Format-Filesize $dellen)] will be " -NoNewline
write-host "permanently deleted" -ForegroundColor Red

$tbd | ForEach-Object {
	if ($_.del.length.length -ge 1) {
		write-host "  " -NoNewline
		write-host "$(($_.mangapath -split "$fsep")[-1])" -NoNewline -ForegroundColor Cyan
		write-host (" " * (($maxlen_of_filename-($_.mangapath -split "$fsep")[-1].length)+2)) -NoNewline
		write-host " Chapters $($_.first) - $($_.secondlast)" -NoNewline -ForegroundColor Red
		write-host (" " * (15-"$($_.first) - $($_.secondlast)".Length)) -NoNewline
		write-host "$($_.del.length.length) files `t$(Format-Filesize $_.dellen)" -ForegroundColor Yellow
	}
}

write-host "`nThis process is " -NoNewline
write-host "irreversible" -NoNewline -ForegroundColor Red
write-host ", and there will be " -NoNewline
write-host "no way to restore deleted files" -NoNewline -ForegroundColor Red
write-host " after this operation."
$continue = Read-Host "Do you want to continue? [Y/n]"

if ($continue -eq "y" -or $continue -eq "Y") {
	$del | ForEach-Object {
		if (Test-Path "$_" -PathType leaf) {
			if ($keep.Contains($_)) {
				write-host "Prevented $_ from being deleted."
			} else {
				remove-item "$_"
			}
		} else {
			write-host "$_ is fake."
		}
	}
	$errors = $false
	$keep | ForEach-Object {
		if (-not (Test-Path "$_") -and $_ -ne "") {
			write-host "ERROR: " -NoNewline -ForegroundColor Red
			write-host "File $_ is missing, even though it was scheduled for keeping."
			$errors = $true
		}
	}

	if ($errors -eq $true) {
		write-host "Exiting with error(s)." -ForegroundColor Red
		exit
	}

	write-host "Deleted $($del.length.length) files."
	write-host "$($keep.length.length) files scheduled for keeping have been verified to exist."
	write-host "Operation successful. Exiting." -ForegroundColor Green
}
else {
	write-host "Aborting."
}