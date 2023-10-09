

#
#	CLEAN.PS1
#	A supplementary script to update.ps1 and dexget.ps1 to remove old downloads.
#	Author: @ryuukumar (https://github.com/ryuukumar)
#





#---------------------------------------#
#  FUNCTIONS                            #
#---------------------------------------#


. "$PSScriptRoot/scripts/functions.ps1"
. "$PSScriptRoot/scripts/defaults.ps1"
. "$PSScriptRoot/scripts/debug.ps1"





#---------------------------------------#
#  ENTRY POINT                          #
#---------------------------------------#


#  0. LOAD SETTINGS

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

$savedir = (Resolve-Path $settings.'general'.'manga-save-directory').Path

$sep = '/'
$fsep = '/'

if ($IsWindows) { $sep = '\' ; $fsep = '\\' }


#  1. BUILD CLEAN LIST

$tbd = [System.Collections.ArrayList]@()
[System.Int128]$dellen = 0
[System.Int128]$keeplen = 0

write-host -NoNewline "Scanning $savedir... "
Get-ChildItem "$savedir" | ForEach-Object {
	if (((($_ -split ' ')[0]) -eq "$savedir$sep(Manga)") -and (test-path $_ -PathType Container)) {
		$files = $(Get-ChildItem "$_")
		$filenos = [System.Collections.ArrayList]@()
		$incompletedls = 0

		foreach ($file in $files.name) {
			[double]$chnum = (($file -split "\)")[0]) -replace '[^0-9.]',''
			if ($chnum -ge 1E+10) { $incompletedls += 1 ; continue }
			$filenos.add($chnum) | out-null
		}
		
		$lastch = [double](($filenos | Measure-Object -Maximum).Maximum)
		$filenos.remove($lastch)
		$secondlastch = [double](($filenos | Measure-Object -Maximum).Maximum)
		$firstch = [double](($filenos | Measure-Object -Minimum).Minimum)

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
			incompletedl = $incompletedls
		}

		foreach($file in $files.name) {
			[double]$chnum = (($file -split "\)")[0]) -replace '[^0-9.]',''
			if ($chnum -ne $lastch) {
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


#  2. FORMALISE CLEAN LIST

$del = [System.Collections.ArrayList]@()
$keep = [System.Collections.ArrayList]@()
$incomplete = 0

$tbd | ForEach-Object {
	$keep.add($_.keeppath) | out-null
	$_.del | ForEach-Object {
		if ($_.path -ne "") {
			$del.add($_.path) | out-null
		}
	}
	$incomplete += $_.incompletedl
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

if ($incomplete -gt 0) {
	write-host "`nAdditionally, the following $($incomplete) incomplete downloads will be " -NoNewline
	write-host "permanently deleted" -ForegroundColor Red

	$tbd | ForEach-Object {
		if ($_.incompletedl -ge 1) {
			write-host "  " -NoNewline
			write-host "$(($_.mangapath -split "$fsep")[-1])" -NoNewline -ForegroundColor Cyan
			write-host (" " * (($maxlen_of_filename-($_.mangapath -split "$fsep")[-1].length)+2)) -NoNewline
			write-host " $($_.incompletedl) incomplete download(s)`n" -NoNewline -ForegroundColor Red
		}
	}

	write-host ""
}

write-host "`nThis process is " -NoNewline
write-host "irreversible" -NoNewline -ForegroundColor Red
write-host ", and there will be " -NoNewline
write-host "no way to restore deleted files" -NoNewline -ForegroundColor Red
write-host " after this operation."
$continue = Read-Host "Do you want to continue? [Y/n]"


#  3. PERFORM CLEAN

if ($continue -eq "y" -or $continue -eq "Y") {
	$del | ForEach-Object {
		if (Test-Path "$_" -PathType leaf) {
			if ($keep.Contains($_)) {
				write-host "Prevented $_ from being deleted."
			} else {
				remove-item "$_" -Recurse -Force
			}
		} else {
			$dirname = ($_ -split "$fsep")[-1]
			$hash = ([regex]::Matches($dirname, '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'))
			if ($dirname.length -eq 36 -and $hash) {
				remove-item "$_" -Recurse
			} else {
				write-host "$_ is a directory and will not be deleted."
			}
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





#---------------------------------------#
#  EXIT                                 #
#---------------------------------------#

