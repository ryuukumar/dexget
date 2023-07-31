
# Quick script to update all the manga listed in updates.txt

if (-not(Test-Path "$(Get-Location)\updates.txt")) {
    write-Host "ERROR: " -NoNewline -ForegroundColor Red
    Write-Host "updates.txt was not found. Please create one with the list of manga you want downloaded."
    exit
}

$file = Get-Content "$(Get-Location)\updates.txt"

foreach ($line in $file) {
    ./dexget.ps1 $line -c -a -C
}