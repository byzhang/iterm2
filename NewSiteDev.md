Development is happening here: https://github.com/jamesarosen/iTerm2/tree/website

# TODO #
  * james: Use header graphic from mock psd (jpg version at www.iterm2.com/dev/header.jpg )
  * james: Show indication of selected top-level menu
  * james: Add code to support second-level menus
  * george: create Download button

# Official Plan #
  * The site should be hosted on Dreamhost
  * The site should be usable on iPhone, but we shouldn't expend a huge effort on making it perfect.
  * Google Analytics will be used
  * The features section will have a left navbar that shows different screenshots in the content area with accompanying text.
  * The support section will have a FAQ and various text documents
  * The dev section will have offsite links to googlecode, etc.
  * Chrome, Firefox, and Safari are the key targets.
  * A mock PSD is here: [http://www.iterm2.com/dev/mock.psd](http://www.iterm2.com/dev/mock.psd)
  * Jekyll for templating
  * try to use CSS3 transitions for browsers that support it
  * fall back to jQuery UI to do the slide transitions for browsers that don't (or if we can't get CSS3 transitions to work)
  * fall back to static page links for JS-less and CSS3-less browsers

# Site Map #
```
- Home [Summary, download button, donate button]
- Features [each subsection includes a screenshot + blurb]
  + Split panes
  + Hotkey
  + Instant Replay
  + Search
  + Transparency
  + Full Screen
  + 256 Colors
  + Autocomplete
  + Mouseless Copy-Paste
  + Paste History
- Compare [compares iTerm2 to Terminal & iTerm in a matrix]
- Support
  + Contact us [link to twitter, mailing list]
  + FAQ [copied from google sites page]
  + Documentation [copied from google sites page]
- Develop [link to googlecode and dev-related wiki pages on googlecode]
```

# Other Ideas #
  * Twitter feed?
  * Need to place the donate button somewhere.
  * We shouldn't use the code that's up now - it's all ripped off from another site
  * Use Github issues to discuss site development
  * Store documentation in Github wiki and use a git import to add them to the site. That way, the same content is available on the site and on the wiki