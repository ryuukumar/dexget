


$pdfconv = {
    param (
        [ref]$chapterqueue
    )

    $settings | Out-Null
    if (Test-Path "preferences.json") { $settings = Get-Content 'preferences.json' | ConvertFrom-Json }
    else { write-dbg "pdfconv could not find preferences.json" -level "error" ; exit }

    while ($true) {
        $pdfc = [System.Collections.ArrayList]@()
        [int]$incompleteconv = 0

        # Build list of img -> pdf pairs
        for ($i=0; $i -lt $chapterqueue.Value.length.length; $i++) {
            $incompleteconv += ($chapterqueue.value[$i].total - $chapterqueue.value[$i].convcomp)
            if ($chapterqueue.value[$i].pdfmade) { continue }
            if (($chapterqueue.value[$i].total - $chapterqueue.value[$i].convcomp) -gt 0) { continue }
            
            $pdfobj = [PSCustomObject]@{
                src = "$($chapterqueue.value[$i].outdir)"
                dest = "$($chapterqueue.value[$i].outdir)/../$($chapterqueue.value[$i].title)"
                cloud = (($chapterqueue.value[$i].clouddir -ne 0) ? "$($chapterqueue.value[$i].clouddir)" : 0)
                i = $i
            }
            $pdfc.add($pdfobj) | out-null
        }

        # Break condition
        if ($pdfc.length -lt 1 -and $incompleteconv -eq 0) {
            write-dbg "pdfconv: Break condition satisfied" -level "info"
            break
        }

        # Convert images to pdf
        $magickcomm = ($IsLinux ? "convert" : "magick convert")
        $pdfc | ForEach-Object -ThrottleLimit $settings.'performance'.'maximum-simultaneous-pdf-conversions' -parallel {
            if ($($using:settings).'performance'.'pdf-method' -eq "magick") {
                Invoke-Expression "$($using:magickcomm) `"$($_.src)/*.jpg`" $($($using:settings).'manga-quality'.'grayscale' ? `
                    "-colorspace Gray" : " ") -compress JPEG -density 80x `"$($_.dest)`""
            }
            elseif ($($using:settings).'performance'.'pdf-method' -eq "pypdf") {
                Invoke-Expression "python.exe -m img2pdf `"$($_.src)/*.jpg`" $($($using:settings).'manga-quality'.'grayscale' ? `
                    "-C L" : " ") -o `"$($_.dest)`""
            }

            $debugmode = ($using:settings).'general'.'debug-mode'
            if ($debugmode) {                   # fuck you powershell why don't you let me use write-dbg here you ginormous piece of shit
                Write-Host "[DEBUG]`t`tFinished saving PDF `"$($_.dest)`"" -ForegroundColor Green
            }

            if ($_.cloud -ne 0) { Copy-Item "$($_.dest)" "$($_.cloud)" }
            remove-item "$($_.src)" -Recurse
            $($using:chapterqueue).value[$_.i].pdfmade = $true
        }

        # wait
        if ($pdfc.length -lt 1) {
            start-sleep -Milliseconds 100
        }
    }
}