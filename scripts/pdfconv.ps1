


$pdfconv = {
    param (
        [ref]$chapterqueue
    )

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
            }
            $pdfc.add($pdfobj)
            $chapterqueue.value[$i].pdfmade = $true
        }

        # Break condition
        if ($pdfc.length -lt 1 -and $incompleteconv -eq 0) {
            break
        }

        # Convert images to pdf
        $pdfc | ForEach-Object {
            magick "$($_.src)/*.jpg" -density 80x -resize "$($width)x" -compress JPEG "$($_.dest)"
            remove-item "$($_.src)" -Recurse
        }

        # wait
        if ($pdfc.length -lt 1) {
            start-sleep -Milliseconds 100
        }
    }
}