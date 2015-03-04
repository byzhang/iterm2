# Introduction #

These instructions are for people who want to build the latest code from github. Expect it to be buggier than releases. Once in a while it might not compile if I mess up (but please let me know!)


# Details #

  * Install XCode from the app store; if you already have it, ensure you have the latest version.
  * Download the source with this command:
```
git clone https://github.com/gnachman/iTerm2.git
```
  * Start XCode.
  * File->Open iterm2/iterm.xcodeproj
  * In the top left, you'll see a pulldown menu that says "iTerm > My Mac 64-bit". Click on the left part (on iTerm) and choose Edit Scheme. Make sure Build Configuration is set to Development for debugging or Deployment for speed.
  * Cmd-R to run.
  * Get a small cup of coffee.
  * If it launches, congratulations. If not, look in the left-hand pane for errors.