# Introduction #

We need 2x resolution images for all iTerm2 graphics. This requires artistic talent as most of the original .PSDs are not around any more.


# Details #

There are a bunch of images in the [images folder on Github](https://github.com/gnachman/iTerm2/tree/master/images) that need to be upgraded to retina. The process is to create a version of the image at twice the resolution (and twice the detail) with @2x inserted before the extension. For example, foo.png gets a foo@2x.png. This will require some level of artistic talent (otherwise I'd do it myself, hah!)

Graphics that are frequently visible must be converted. Those are high priority. There are also rarely seen graphics, which should be converted but it's not urgent. These are low priority.

## Process ##
Want to volunteer? Make a comment saying which image you want to work on. File a bug report with the retina version of the image attached. I'll remove items from this wiki as they're completed.

## Images ##

### High Priority ###
All high priority images are done.

Icons in the prefs window.

### Low Priority ###

  * BroadcastInput.png

Shown in the top right of a terminal when input is broadcast.

  * Coprocess.png
  * Coprocess.psd

Shown in the top right of a terminal when a coprocess is running.


  * wrap\_to\_bottom.png (see wrap.psd for source image)
  * wrap\_to\_top.png

Shown when a search wraps around the top/bottom of the terminal.

  * config.png

Shows in the toolbar to open "show info" window.

  * newwin.png

Shows in toolbar to open a new window.

### Done ###

  * bell.png

Shown when the bell rings.


  * PrefsGeneral.tiff
  * PrefsKeyboard.tiff
  * PrefsMouse.tiff (see PrefsMouse-big.tiff for a larger source image)
  * arrangement.png
  * arrangement.psd
Also needs a new "profiles" icon because the system icon is now colored and looks wrong in 10.8.

  * IBarCursor.png

Mouse cursor. Note: Must look good against both light and dark backgrounds.

  * IBarCursorXMR.png

Mouse cursor when XCode Mouse Reporting is on.  Note: Must look good against both light and dark backgrounds.

  * closebutton.tif

Tab close button.

  * important.png

Bell icon shown in tab when the bell rings in a background tab.
Note: It would be nice to have a more minimal, less "photographic" look for this.

  * star-gold24.png

Indicates that a bookmark is the default.
Note: It would be nice to use a more minimal icon for this.