

#
#	UPDATE.PS1
#	Quick script to update all the manga listed in updates.txt
#	Author: @ryuukumar (https://github.com/ryuukumar)
#





#---------------------------------------#
#  FUNCTIONS                            #
#---------------------------------------#


. "$PSScriptRoot/scripts/functions.ps1"
. "$PSScriptRoot/scripts/defaults.ps1"
. "$PSScriptRoot/scripts/debug.ps1"





#---------------------------------------#
#  ENTRY POINT                          #
#---------------------------------------#


if (-not(Test-Path "$(Get-Location)/updates.txt")) {
    write-dbg "updates.txt was not found. Please create one with the list of manga you want downloaded." -level "error"
    exit
}

$file = Get-Content "$(Get-Location)/updates.txt"

foreach ($line in $file) {
    ./dexget.ps1 $line -c -a -C --no-banner     # leap of faith
}





#---------------------------------------#
#  EXIT                                 #
#---------------------------------------#

