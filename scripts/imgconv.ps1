


[scriptblock]$imgconv = {
    param (
        [ref]$chapterqueue
    )

    $settings | Out-Null
    if (Test-Path "../preferences.json") { $settings = Get-Content '../preferences.json' | ConvertFrom-Json }
    elseif (Test-Path "../../preferences.json") { $settings = Get-Content '../../preferences.json' | ConvertFrom-Json }
    else { write-host "i am confusion." ; exit }

    while ($true) {
        $imgconv = [System.Collections.ArrayList]@()
        [int]$incompletedl = 0

        # build imgconv
        for ($i=0; $i -lt $chapterqueue.Value.length.length; $i++) {
            $incompletedl += ($chapterqueue.value[$i].total - $chapterqueue.value[$i].dlcomp.length.length)
            if ($chapterqueue.value[$i].toconv.length -lt 1) { continue }
            for ($j=[int]($chapterqueue.value[$i].toconv.length.length) - 1; $j -ge 0; $j--) {          # it doesn't work if i put a single .length
                $imgconv.Add($chapterqueue.value[$i].toconv[$j])                                        # if you know why, PLEASE TELL ME!!
                $chapterqueue.value[$i].toconv.removeat($j)                                             # because this looks stupid!!!
            }
        }

        # break condition
        if ($incompletedl -eq 0 -and $imgconv.length -lt 1) { 
            write-host "Break condition satisfied"
            break
        }

        # figure out convert conditions
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
            write-host "Found $($imgconv.length) images to convert"
        }

        $mutex = [hashtable]::Synchronized(@{
            Mutex = [System.Threading.Mutex]::new()
        })

        $imgconv | ForEach-Object -throttlelimit $settings.'performance'.'maximum-simultaneous-conversions' -Parallel {
            Invoke-Expression "magick convert `"$($_.src)[0]`" -resize $($($using:settings).'manga-quality'.'page-width')x $($using:magickargs) `"$($_.dest)`""
            if ($($using:mutex)['Mutex'].WaitOne()) {
                ($using:chapterqueue).Value[$_.index].convcomp++
                remove-item "$($_.src)"
                $($using:mutex)['Mutex'].ReleaseMutex()
            }
        }

        # if we didn't convert any images, wait
        if ($imgconv.length -lt 1) {
            write-host "Nothing to convert"
            Start-Sleep -Milliseconds 100
        }
    }
}