


$progdisp = {
    param(
        [ref]$chapterqueue
    )

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

        ### patch up dl lagging behind conv due to parallelization (fuck you ps)
        if ($imgdlprog -lt $imgconvprog) { $imgdlprog = $imgconvprog }

        # update pdf conversion progress
        $pdfprog = 0
        $chapterqueue.value | foreach-object {
            $pdfprog += [int]($_.pdfmade ? 1 : 0)
        }

        # display progress
        $pos = $host.UI.RawUI.CursorPosition
	    $pos.Y -= 3
	    $host.UI.RawUI.CursorPosition = $pos

        show-progress $imgdlprog    $imgdltotal     "Imgdl   : "    $(([string]$imgdltotal).length * 2 + 3)
        show-progress $imgconvprog  $imgconvtotal   "Imgconv : "    $(([string]$imgdltotal).length * 2 + 3)
        show-progress $pdfprog      $pdftotal       "Pdfconv : "    $(([string]$imgdltotal).length * 2 + 3)

        # break condition
        if ($imgdlprog -eq $imgdltotal -and $imgconvprog -eq $imgconvtotal -and $pdfprog -eq $pdftotal) { break }

        # pause
        Start-Sleep -Milliseconds 250
    }
}