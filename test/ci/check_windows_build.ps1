# Check of the exported Windows build (a smoke check of the real .exe).
# It starts the game with no window for a few seconds, then checks the exit code and the log.
# Usage: .\check_windows_build.ps1 -BuildDir "dist/windows"

param(
    [string]$BuildDir = "dist/windows" # the folder with the exported .exe and .pck files
)

$MaxWaitSeconds = 60 # how long we wait for the game to finish, after that we stop it by force
$QuitAfterFrames = 300 # the game closes itself after this many frames
$MainSceneMarker = "Completed load for: 'res://scenes/main_menu.tscn'" # this log line appears when the main menu is loaded
$FailureLines = @() # here we collect the reasons why the check failed, an empty list at the end means success

$BuildDir = (Resolve-Path $BuildDir).Path # turn the folder into a full path, so Godot finds the log file from any place
$LogFile = Join-Path $BuildDir "game_check.log" # the log file of this run, it lies next to the game
if (Test-Path $LogFile) { Remove-Item $LogFile } # remove the log of an older run, so we never read old lines

$GameExe = Get-ChildItem -Path $BuildDir -Filter "*.exe" | Select-Object -First 1 # the first .exe in the folder is the game
if (-not $GameExe) { # no .exe found, there is nothing to check
    Write-Host "FAIL: no .exe file in $BuildDir"
    exit 1 # exit code 1 = red cross in CI (continuous integration)
}
Write-Host "Checking: $($GameExe.Name)"

# Start the game: no window (--headless), close after N frames, write a detailed log (--verbose) to our file
$GameArguments = @("--headless", "--quit-after", "$QuitAfterFrames", "--verbose", "--log-file", "`"$LogFile`"") # the quotes around the log path protect spaces in it
$GameProcess = Start-Process -FilePath $GameExe.FullName -ArgumentList $GameArguments -PassThru # start the game and keep its process object
$null = $GameProcess.Handle # touching Handle makes Windows PowerShell remember the exit code after the process ends
$Finished = $GameProcess.WaitForExit($MaxWaitSeconds * 1000) # wait for the end, the time is in milliseconds

if (-not $Finished) { # the game did not close in time, it is hanging
    $GameProcess.Kill() # stop the game by force
    $FailureLines += "The game did not finish in $MaxWaitSeconds seconds (it hangs)"
} elseif ($GameProcess.ExitCode -ne 0) { # the game ended, but with an error code
    $FailureLines += "Exit code is $($GameProcess.ExitCode), expected 0"
}

# Read the log of the run
if (-not (Test-Path $LogFile)) { # no log file means the game did not even start to write it
    $FailureLines += "The log file was not created"
    $LogLines = @() # an empty log, so the next checks do not crash
} else {
    $LogLines = Get-Content $LogFile # every line of the log becomes one item of the list
}

# Check 1: the main menu scene was loaded
if (-not ($LogLines | Where-Object { $_.Contains($MainSceneMarker) })) { # no log line contains the marker text
    $FailureLines += "The main menu was not loaded (no line: $MainSceneMarker)"
}

# Check 2: there are no error lines, except the harmless one that Godot prints when we close the game early
$ErrorLines = $LogLines | Where-Object { # keep only the lines that look like an error...
    ($_ -match "^(SCRIPT ERROR|USER ERROR|ERROR|Parse Error)") -and ($_ -notmatch "still in use at exit") # ...and are not the known harmless one
}
foreach ($Line in $ErrorLines) { # one failure reason for every bad line
    $FailureLines += "Error in the log: $Line"
}

# The result
if ($FailureLines.Count -gt 0) { # at least one check failed
    Write-Host "FAIL: the Windows build check found problems:"
    foreach ($Reason in $FailureLines) { Write-Host " - $Reason" } # print every reason
    Write-Host "--- game log ---"
    $LogLines | ForEach-Object { Write-Host $_ } # show the whole log, it helps to find the cause
    exit 1
}
Write-Host "OK: the game started, the main menu was loaded, no errors in the log"
exit 0