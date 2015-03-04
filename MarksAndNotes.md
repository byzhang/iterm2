# Introduction #

iTerm2 allows you to set marks in history that are easy to navigate and also annotate regions of text. A specific implementation of this idea can be found at http://www.iterm2.com/shell_integration.html.

### Marks ###
You can use Cmd-Shift-Up and Down Arrow to navigate "marks" in your terminal history (e.g., to find previous shell prompts).  Marks can be set with Shell>Set Mark, but more usefully, they can be set with an escape code:

` \033]50;SetMark\007 `

The mark is indicated visually with a small blue triangle in the left margin.
![http://www.iterm2.com/images/mark.png](http://www.iterm2.com/images/mark.png)

If you kick off a long-running command, **Edit>Alert on next mark** will post a notification (Growl or Notification Center) and bounce the dock icon when the command finishes.

Note, however, that a more powerful (but complex) technique for setting marks is described below in _Command History_.

### Notes ###
A mark with an annotation attached is called a note. You can add a note with:

` \033]50;AddNote=value\007 `

or

` \033]50;AddHiddenNote=value\007 `

_value_ is one of:
  * _string_: A region beginning at the current cursor position and extending to the end of the line will be annotated with _string_.
  * _string|length_: A region beginning at the current cursor position and extending _length_ characters will be annotated with _string_.
  * _string|length|x|y_: A region beginning at _x_, _y_ and extending _length_ characters will be annotated with _string_. _x_ and _y_ are 0-based.

_AddNote_ adds a note with a visible annotation, while _AddHiddenNote_ collapses the annotation automatically. Right-clicking on the annotation and selecting "Show Notes" will reveal the annotations. All annotations can be toggled with Edit>Show/Hide Notes.

Notes can also be added manually by selecting a region of text and choosing **Annotate selection** in the context menu:
![http://iterm2.com/images/notes.png](http://iterm2.com/images/notes.png)