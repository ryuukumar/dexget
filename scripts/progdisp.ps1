


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
    $imgconvprog = 1
    $pdfprog = 1

    $imgdltotal = 0
    $imgconvtotal = 1
    $pdftotal = 1

    $chapterqueue.value | foreach-object {
        $imgdltotal += $_.total
    }

    while ($true) {
        # update imgdl progress
        $imgdlprog = 0
        $chapterqueue.value | foreach-object {
            $imgdlprog += $_.completed
        }

        # update img conversion progress

        # update pdf conversion progress

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