# Steps for Reporting Unreproducable Bugs #

Sometimes there is a really hairy bug where a simple description does not suffice to reproduce it. In that case, follow these steps.

  * Go to the iTerm menu and select "Toggle Debug Logging".
  * Reproduce your bug (don't take too long, the log gets big fast).
  * Select "Toggle Debug Logging" again to turn off the log.
  * cd /tmp
  * gzip debug\_log.txt
  * Open /Applications/Utilities/Console
  * Enter a search for "iterm". If there is anything there:
    * Cmd-A to select all
    * File->Save Selection As
  * Open a [new issue](http://code.google.com/p/iterm2/issues/entry).
  * Attach three files to the bug:
    1. /tmp/debug\_log.txt.gz
    1. Saved console output, if any
    1. $HOME/Library/Preferences/com.googlecode.iterm2.plist
> > Note: the com.googlecode.iterm2.plist file will contain your hostnames and paste history (if you opted to save it to disk). Do not upload it if there is a privacy concern.