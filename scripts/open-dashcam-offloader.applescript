set launcherPath to POSIX path of (path to me)
set launcherFolder to do shell script "dirname " & quoted form of launcherPath
set appPath to launcherFolder & "/Dashcam Offloader.app"

try
	do shell script "test -d " & quoted form of appPath
on error
	display alert "Dashcam Offloader not found" message "Put this launcher in the same folder as Dashcam Offloader.app, then run it again." as warning
	return
end try

do shell script "xattr -dr com.apple.quarantine " & quoted form of appPath
do shell script "open " & quoted form of appPath
