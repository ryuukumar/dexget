


[scriptblock]$imgdl = {
    param(
        [ref]$chapterqueue
    )

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

    foreach ($chapter in $chapterqueue.value) {
        foreach ($img in $chapter.images) {
            $newimg = [PSCustomObject]@{
                img = $img
                out = "$($chapter.outdir)\$img"
            }
            $imglist.Add($newimg)
        }
    }
    
    # Define the script block for the download job
    $scriptBlock = {
        param($url, $outputPath, $filesize, $i, $images)
        
        (New-Object System.Net.WebClient).DownloadFile($url, $outputPath)
    }

    # Create the folder for each chapter
    if (-not (test-path "$wd\$id")) {
        mkdir "$wd\$id" | out-null
    }

    $i=0

    # Create an array to hold the download jobs
    $downloadJobs = @()

    # Downloads each image from imglist
    foreach ($img in $imglist) {
        $i++
        $filesize = Get-WebSize("$baseUr/data/$hash/$img")
        $filename = $(add-zeroes $i $images) + "." + $(Get-FileType $img)
        $url = "$baseUr/data/$hash/$img"
        $outputPath = "$wd/$id/$filename"
        
        # Start the download job
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $url, $outputPath, $filesize, $i, $images
        
        # Add the job to the download jobs array
        $downloadJobs += $job
        
        # If there are already the maximum number of download jobs running, wait for one to complete before starting another
        if ($downloadJobs.Count -eq $maxConcurrentJobs) {
            $finishedJob = $downloadJobs | Wait-Job -Any
            $downloadJobs.Remove($finishedJob)
        }
    }

    # Wait for any remaining download jobs to complete
    $downloadJobs | Wait-Job | Out-Null
}