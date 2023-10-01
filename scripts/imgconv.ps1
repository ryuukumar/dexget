


[scriptblock]$imgconv = {
    param (
        [ref]$chapterqueue
    )

    $settings | Out-Null
    if (Test-Path "preferences.json") { $settings = Get-Content 'preferences.json' | ConvertFrom-Json }
    else { write-host "[ERROR]`tpdfconv could not find preferences.json" -ForegroundColor Red ; exit }

    while ($true) {
        $imgconv = [System.Collections.ArrayList]@()
        [int]$incompletedl = 0

        # build imgconv
        for ($i=0; $i -lt $chapterqueue.Value.length.length; $i++) {
            $incompletedl += ($chapterqueue.value[$i].total - $chapterqueue.value[$i].dlcomp.length.length)
            if ($chapterqueue.value[$i].toconv.length -lt 1) { continue }
            for ($j=[int]($chapterqueue.value[$i].toconv.length.length) - 1; $j -ge 0; $j--) {          # it doesn't work if i put a single .length
                $imgconv.Add($chapterqueue.value[$i].toconv[$j]) | Out-Null                             # if you know why, PLEASE TELL ME!!
                $chapterqueue.value[$i].toconv.removeat($j)                                             # because this looks stupid!!!
            }
        }

        # break condition
        if ($incompletedl -eq 0 -and $imgconv.length -lt 1) { 
            write-host "[INFO]`timgconv: Break condition satisfied" -ForegroundColor Blue
            break
        }

        # figure out convert conditions
        $magickcomm = ($IsLinux ? "convert" : "magick convert")

        $magickargs = ""
        if ($settings.'manga-quality'.'grayscale' -eq $true) {
            $magickargs = "-colorspace Gray "
        }
        switch ($settings.'manga-quality'.'quality') {
            "low" {
                $magickargs += "-quality 40 -adaptive-blur 2 -despeckle"
                break
            }
            "medium" {
                $magickargs += "-quality 90 -despeckle"
                break
            }
            "high" {
                $magickargs += "-quality 95"
                break
            }
            Default {}
        }

        # convert images
        if ($imgconv.length -gt 0) {
            write-host "[INFO]`tFound $($imgconv.length.length) images to convert" -ForegroundColor Blue
        }

        $mutex = [hashtable]::Synchronized(@{
            Mutex = [System.Threading.Mutex]::new()
        })

        $imgconv | ForEach-Object -throttlelimit $settings.'performance'.'maximum-simultaneous-conversions' -Parallel {
            Invoke-Expression "$($using:magickcomm) `"$($_.src)[0]`" -resize $($($using:settings).'manga-quality'.'page-width')x $($using:magickargs) `"$($_.dest)`""
            write-host "[DEBUG] Finished converting `"$($_.src)[0]`" to `"$($_.dest)`"" -ForegroundColor Green
            if ($($using:mutex)['Mutex'].WaitOne()) {
                ($using:chapterqueue).Value[$_.index].convcomp++
                remove-item "$($_.src)"
                $($using:mutex)['Mutex'].ReleaseMutex()
            }
        }

        # if we didn't convert any images, wait
        if ($imgconv.length -lt 1) {
            write-host "[INFO] Nothing to convert" -ForegroundColor Blue
            Start-Sleep -Milliseconds 100
        }
    }
}