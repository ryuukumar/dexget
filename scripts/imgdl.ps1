


[scriptblock]$imgdl = {
    param(
        [ref]$chapterqueue
    )

    $baseUr = "https://uploads.mangadex.org"
    $maxConcurrentJobs = 20

    function Get-WebSize ([string]$url) {
        $HttpWebResponse = $null
        $HttpWebRequest = [System.Net.HttpWebRequest]::Create($url)
        try {
            $HttpWebResponse = $HttpWebRequest.GetResponse()
            $HttpWebResponse.close()
            return $HttpWebResponse.ContentLength
        }
        catch {
            $_ | ConvertTo-Json
        }
    }
    
    function Get-FileType([string]$filename) {
        return $filename.Split('.')[-1]
    }
    
    function Add-Zeroes {
        param (
            [int]$target,
            [int]$maxval
        )
        return $target.ToString().PadLeft(([string]$maxval).Length, '0')
    }

    $imglist = [System.Collections.ArrayList]@()

    $j = 0
    foreach ($chapter in $chapterqueue.value) {
        $i = 0
        foreach ($img in $chapter.images) {
            $newimg = [PSCustomObject]@{
                img = "$baseUr/data/$($chapter.hash)/$img"
                out = "$($chapter.outdir)\$(Add-Zeroes $i $chapter.total).png"
                counter = ([ref]($chapterqueue.Value[$j].completed))
            }
            $imglist.Add($newimg)
            $i++
        }
        if (-not(Test-Path $chapter.outdir)) {
            mkdir $chapter.outdir | out-null
        }
        $j++
    }

#    foreach ($img in $imglist) {
#        write-host "$($img.img) -> $($img.out)"
#    }
    
    # Define the script block for the download job
    $scriptBlock = {
        param($url, $outputPath, $complete)
        (New-Object System.Net.WebClient).DownloadFile($url, $outputPath)
        & { $complete.value++ }
    }

    # Create an array to hold the download jobs
    $downloadJobs = [System.Collections.ArrayList]@()

    # Downloads each image from imglist
    foreach ($img in $imglist) {
        # Start the download job
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $img.img, $img.out, $img.counter
        write-host "Started $($img.out) [$($img.counter.value) : $($img.counter)]"
        
        # Add the job to the download jobs array
        $downloadJobs.add($job)
        
        # If there are already the maximum number of download jobs running, wait for one to complete before starting another
        if ($downloadJobs.Count -eq $maxConcurrentJobs) {
            $finishedJob = $downloadJobs | Wait-Job -Any
            $downloadJobs.Remove($finishedJob)
        }
    }

    # Wait for any remaining download jobs to complete
    $downloadJobs | Wait-Job | Out-Null

    write-host "Downloads complete."
}
