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

# Function to convert a list of numbers into a string of ranges
function ConvertTo-RangeString {
	param ( [System.Collections.ArrayList]$Numbers )

	$result = ""
	$start = $null
	$end = $null

	for ($i = 0; $i -lt $Numbers.Count; $i++) {
		if ($null -eq $start) { $start = $Numbers[$i] }
		
		$end = $Numbers[$i]

		if ($i -eq $Numbers.Count - 1 -or $Numbers[$i] + 1 -ne $Numbers[$i + 1]) {
			if ($start -eq $end) { $result += "$start, " }
			else { $result += "$start-$end, " }
			$start = $null
		}
	}

	return $result.TrimEnd(", ")
}
