


$progdisp = {
    param(
        [ref]$chapterqueueorig,
        [bool]$jsonprogress
    )

    $settings | Out-Null
    if (Test-Path "../preferences.json") { $settings = Get-Content '../preferences.json' | ConvertFrom-Json }
    elseif (Test-Path "../../preferences.json") { $settings = Get-Content '../../preferences.json' | ConvertFrom-Json }
    else { write-host "i am confusion." }
   

    function show-progress {
        param (
            [double]$part,
            [double]$total,
            [string]$pre="",
            [int]$postlen=10
        )

        $progbarlength = ([int]$($Host.UI.RawUI.WindowSize.Width)) - ($pre.length + $postlen + 7)

        $fill = $progbarlength * [double]($part/$total)

        write-host "$pre [" -NoNewline
        if ($part -eq $total) {
            write-host ("=" * $fill) -NoNewline -ForegroundColor Green
        }
        else {
            write-host ("=" * ($fill)) -NoNewline -ForegroundColor Yellow
            write-host (" " * ($progbarlength - $fill)) -NoNewline
        }
        write-host "] [$part/$total]  "

    }

    function json-total {
        param (
            [int]$imgdltotal,
            [int]$imgconvtotal,
            [int]$pdftotal
        )

        $output = [PSCustomObject]@{
            type = "count"
            dldtotal = $imgdltotal
            cnvtotal = $imgconvtotal
            pdftotal = $pdftotal
        }

        write-host ($output | ConvertTo-Json -Compress)
    }

    function json-progress {
        param (
            [int]$imgdlprog,
            [int]$imgconvprog,
            [int]$pdfprog
        )

        $output = [PSCustomObject]@{
            type = "progress"
            dldprog = $imgdlprog
            cnvprog = $imgconvprog
            pdfprog = $pdfprog
        }

        write-host ($output | ConvertTo-Json -Compress)
    }

    $imgdlprog = 0
    $imgconvprog = 0
    $pdfprog = 0

    $imgdltotal = 0
    $imgconvtotal = 0
    $pdftotal = 0

    $chapterqueue = ($chapterqueueorig.value.clone())

    $chapterqueue | foreach-object {
        $imgdltotal += $_.total
        $pdftotal++
    }
    $imgconvtotal = $imgdltotal

    if ($jsonprogress -eq $true) {
        json-total $imgdltotal $imgconvtotal $pdftotal
    }

    while ($true) {
        # update imgdl progress
        $imgdlprog = 0
        $chapterqueue | foreach-object {
            $imgdlprog += $_.dlcomp.length.length
        }

        # update img conversion progress
        $imgconvprog = 0
        $chapterqueue | foreach-object {
            $imgconvprog += $_.convcomp
        }

        #if ($imgdlprog -lt $imgconvprog) { $imgdlprog = $imgconvprog }

        # update pdf conversion progress
        $pdfprog = 0
        $chapterqueue | foreach-object {
            $pdfprog += [int]($_.pdfmade ? 1 : 0)
        }

        if ($jsonprogress) {
            json-progress $imgdlprog $imgconvprog $pdfprog
        }
        else {
            # display progress
            $pos = $host.UI.RawUI.CursorPosition
            $pos.Y -= 3
            $host.UI.RawUI.CursorPosition = $pos

            show-progress $imgdlprog    $imgdltotal     "Download      "    $(([string]$imgdltotal).length * 2 + 2)
            show-progress $imgconvprog  $imgconvtotal   "Compression   "    $(([string]$imgdltotal).length * 2 + 2)
            show-progress $pdfprog      $pdftotal       "PDF Conversion"    $(([string]$imgdltotal).length * 2 + 2)
        }

        # break condition
        if ($imgdlprog -eq $imgdltotal -and $imgconvprog -eq $imgconvtotal -and $pdfprog -eq $pdftotal) { break }

        # pause
        Start-Sleep -Milliseconds 200
    }

    if ($jsonprogress) {
        $output = [PSCustomObject]@{
            type = "complete"
        }
        write-host ($output | ConvertTo-Json -Compress)
    }
}