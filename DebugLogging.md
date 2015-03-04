# Steps for creating a debug log #

  * Go to the iTerm menu and select "Toggle Debug Logging".
  * Reproduce your bug (don't take too long, the log gets big fast).
  * Select "Toggle Debug Logging" again to turn off the log. **This is important! The log will be almost empty otherwise.**
  * cd /tmp
  * gzip debuglog.txt
  * Attach tmp/debuglog.txt.gz to the issue.