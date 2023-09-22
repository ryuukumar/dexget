


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
                dst = "$($chapter.outdir)\$(Add-Zeroes $i $chapter.total).jpg"
                index = $j
            }
            $imglist.Add($newimg)
            $i++
        }
        if (-not(Test-Path $chapter.outdir)) {
            mkdir $chapter.outdir | out-null
        }
        $j++
    }

    $mutex = New-Object System.Threading.Mutex($false, 'Global\MyMutex')

    $imglist | ForEach-Object -throttlelimit $maxConcurrentJobs -Parallel {
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
        
        $mutex.WaitOne() | Out-Null
        try {
            ($using:chapterqueue).value[$_.index].toconv.add($toconvobj)
            ($using:chapterqueue).value[$_.index].dlcomp.add($dldoneobj)
        }
        finally {
            $mutex.ReleaseMutex()
        }
    }
}
