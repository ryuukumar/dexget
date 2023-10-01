


[scriptblock]$imgdl = {
    param(
        [ref]$chapterqueue
    )

    $settings | Out-Null
    if (Test-Path "preferences.json") { $settings = Get-Content 'preferences.json' | ConvertFrom-Json }
    else { write-host "[ERROR]`tpdfconv could not find preferences.json" -ForegroundColor Red ; exit }


    $baseUr = "https://uploads.mangadex.org"

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
        if (-not(Test-Path $chapter.outdir)) {
            write-host "[INFO]`tCreated $($chapter.outdir)" -ForegroundColor Blue
            mkdir $chapter.outdir | out-null
        }

        $i = 0
        foreach ($img in $chapter.images) {
            $fullpath = $(resolve-path $chapter.outdir).Path
            $newimg = [PSCustomObject]@{
                img = "$baseUr/data/$($chapter.hash)/$img"
                out = "$fullpath/$(Add-Zeroes $i $chapter.total).png"
                dst = "$fullpath/$(Add-Zeroes $i $chapter.total).jpg"
                index = $j
            }
            $imglist.Add($newimg) | out-null
            $i++
        }
        $j++
    }

    $mutex = [hashtable]::Synchronized(@{
        Mutex = [System.Threading.Mutex]::new()
    })

    $imglist | ForEach-Object -throttlelimit $settings.'performance'.'maximum-simultaneous-downloads' -Parallel {
        $client = (New-Object System.Net.WebClient)
	    $client.Headers.add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0')
        $client.DownloadFile($_.img, $_.out)
        $toconvobj = [PSCustomObject]@{
            src = $_.out
            dest = $_.dst
            index = $_.index
        }
        $dldoneobj = [PSCustomObject]@{
            out = $_.out
        }
        
        if ($($using:mutex)['Mutex'].WaitOne()) {
            ($using:chapterqueue).value[$_.index].toconv.add($toconvobj) | out-null
            ($using:chapterqueue).value[$_.index].dlcomp.add($dldoneobj) | out-null
            $($using:mutex)['Mutex'].ReleaseMutex()
        }

        write-host "[DEBUG]`tFinished downloading $($_.img) to $($_.out)" -ForegroundColor Green
    }

    $cnt = 0
    $chapterqueue.value | foreach-object {
        $cnt += $_.dlcomp.length.length
    }
    write-host "[INFO]`tFinished downloading $cnt images." -ForegroundColor Blue
}
