# Introduction #

Want to fix some bugs or add some features? Here's what to do.

# Details #

For any change, but especially new features, please post on the discussion list about what you plan to do. iTerm2 is complex in ways that might surprise you, and it's best to have a fully baked idea before diving in on anything big.

  * How do I submit a change?

For small stuff post a patch in the bug tracker. If you want to make regular contributions, mail the list and a branch will be created for you. Google Code has a
code review mechanism so branches can be reviewed before being integrated with the mainline. There's a todo-list item to switch to Mercurial, but I'm making really fast progress right now and I don't want to go yak shaving.

  * What are the lowest targeted OS and developer tools versions?

Use 10.6 or newer for development and XCode 4.x.

  * Can Objc 2.0 features (like properties and fast enumeration) be used?

If you're doing something that won't work in 10.5 or newer, please let me know first. Otherwise, go nuts.

  * Is there a style guide to adhere to?

I've been using this:

[Google Objective-C Style Guide](http://google-styleguide.googlecode.com/svn/trunk/objcguide.xml)

But the line length limit is relaxed because Xcode doesn't work well
with breaking up method invocations like:

```
[foo bar:[baz frotz:[blah spoo]]]
```

Also, use 4 space indents instead of the 2-space indents in the style guide.

A lot of the code does not meet the style guide, but I fix it up as I go.