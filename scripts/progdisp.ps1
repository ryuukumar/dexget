


$progdisp = {
    param(
        [ref]$chapterqueue
    )

    function show-progress {
        param (
            [double]$part,
            [double]$total,
            [string]$pre=""
        )

        $progbarlength = ([int]$($Host.UI.RawUI.WindowSize.Width)) - ($pre.length + ([string]$total).length * 2 + 12)

        $fill = $progbarlength * [double]($part/$total)

        write-host "$pre [" -NoNewline
        for ($i=0; $i -lt $fill; $i++) { write-host "=" -NoNewline }
        for ($i=$fill; $i -lt $progbarlength; $i++) { write-host " " -NoNewline }
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
            $imgdlprog += $_.dlcomp
        }

        # update img conversion progress
        $imgconvprog = 0
        $chapterqueue.value | foreach-object {
            $imgconvprog += $_.convcomp
        }

        # update pdf conversion progress
        $pdfprog = 0
        $chapterqueue.value | foreach-object {
            $pdfprog += [int]($_.pdfmade ? 1 : 0)
        }

        # display progress
        $pos = $host.UI.RawUI.CursorPosition
	    $pos.Y -= 3
	    $host.UI.RawUI.CursorPosition = $pos

        show-progress $imgdlprog    $imgdltotal     "Imgdl   : "
        show-progress $imgconvprog  $imgconvtotal   "Imgconv : "
        show-progress $pdfprog      $pdftotal       "Pdfconv : "

        # break condition
        if ($imgdlprog -eq $imgdltotal -and $imgconvprog -eq $imgconvtotal -and $pdfprog -eq $pdftotal) { break }

        # pause
        Start-Sleep -Milliseconds 250
    }
}