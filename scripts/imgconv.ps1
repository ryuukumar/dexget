


[scriptblock]$imgconv = {
    param (
        [ref]$chapterqueue,
        [int]$width
    )

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

        # convert images
        if ($imgconv.length -gt 0) {
            write-host "Found $($imgconv.length) images to convert"
        }
        $imgconv | ForEach-Object {
            Invoke-Expression "magick convert `"$($_.src)[0]`" -quality 90 -resize $($width)x `"$($_.dest)`""
            $chapterqueue.Value[$_.index].convcomp++
            remove-item "$($_.src)"
        }

        # if we didn't convert any images, wait
        if ($imgconv.length -lt 1) {
            write-host "Nothing to convert"
            Start-Sleep -Milliseconds 100
        }
    }
}