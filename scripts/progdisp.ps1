


$progdisp = {
    param(
        [ref]$chapterqueue
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

    $imgdlprog = 0
    $imgconvprog = 0
    $pdfprog = 0

    $imgdltotal = 0
    $imgconvtotal = 0
    $pdftotal = 0

    $chapterqueue.value | foreach-object {
        $imgdltotal += $_.total
        $pdftotal++
    }
    $imgconvtotal = $imgdltotal

    while ($true) {
        # update imgdl progress
        $imgdlprog = 0
        $chapterqueue.value | foreach-object {
            $imgdlprog += $_.dlcomp.length.length
        }

        # update img conversion progress
        $imgconvprog = 0
        $chapterqueue.value | foreach-object {
            $imgconvprog += $_.convcomp
        }

        #if ($imgdlprog -lt $imgconvprog) { $imgdlprog = $imgconvprog }

        # update pdf conversion progress
        $pdfprog = 0
        $chapterqueue.value | foreach-object {
            $pdfprog += [int]($_.pdfmade ? 1 : 0)
        }

        # display progress
        $pos = $host.UI.RawUI.CursorPosition
	    $pos.Y -= 3
	    $host.UI.RawUI.CursorPosition = $pos

        show-progress $imgdlprog    $imgdltotal     "Download      "    $(([string]$imgdltotal).length * 2 + 2)
        show-progress $imgconvprog  $imgconvtotal   "Compression   "    $(([string]$imgdltotal).length * 2 + 2)
        show-progress $pdfprog      $pdftotal       "PDF Conversion"    $(([string]$imgdltotal).length * 2 + 2)

        # break condition
        if ($imgdlprog -eq $imgdltotal -and $imgconvprog -eq $imgconvtotal -and $pdfprog -eq $pdftotal) { break }

        # pause
        Start-Sleep -Milliseconds 200
    }
}