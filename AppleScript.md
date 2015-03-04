iTerm features AppleScript support. It is documented here. Someone who doesn't hate AppleScript should improve this page :)

Note: See trunk/iTerm.scriptSuite for a schema of the supported objects.

# Example #
<pre>


tell application "iTerm"<br>
activate<br>
<br>
-- Create a new terminal window...<br>
set myterm to (make new terminal)<br>
<br>
-- ... and go on within this one.<br>
tell myterm<br>
-- Set the terminal size constraints.<br>
set number of columns to 30<br>
set number of rows to 30<br>
<br>
-- Array/List which will hold all our sessions (empty<br>
-- by default OFC).<br>
set sessionList to {}<br>
<br>
-- Create a few blank new sessions (will be replaced by<br>
-- automatic calculations later, so that we'll have a<br>
-- nice bar full with new tabs.)<br>
repeat with i from 1 to 2 by 1<br>
launch session "Default"<br>
end repeat<br>
<br>
-- DEBUG: print the session list.<br>
return sessionList<br>
<br>
end tell<br>
<br>
-- set the bounds of the first window to {w, x, y, z}<br>
end tell<br>
</pre>

# Example 2 #
<pre>

tell application "iTerm"<br>
activate<br>
<br>
-- close the first session<br>
terminate the first session of the first terminal<br>
<br>
-- make a new terminal<br>
set myterm to (make new terminal)<br>
<br>
-- talk to the new terminal<br>
tell myterm<br>
<br>
-- make a new session<br>
set mysession to (make new session at the end of sessions)<br>
<br>
-- set size<br>
set number of columns to 100<br>
set number of rows to 50<br>
<br>
-- talk to the session<br>
tell mysession<br>
<br>
-- set some attributes<br>
set name to "tcsh"<br>
set foreground color to "red"<br>
set background color to "blue"<br>
set transparency to "0.6"<br>
<br>
-- execute a command<br>
exec command "/bin/tcsh"<br>
<br>
end tell -- we are done talking to the session<br>
<br>
-- we are back to talking to the terminal<br>
<br>
-- launch a default shell in a new tab in the same terminal<br>
launch session "Default Session"<br>
<br>
-- launch a saved session from the addressbook.<br>
launch session "Root Shell"<br>
-- select the previous session<br>
select mysession<br>
-- get the tty name of a session<br>
set myttyname to the tty of the first session<br>
-- refer to a session by its tty/id<br>
tell session id myttyname<br>
set foreground color to "yellow"<br>
end tell<br>
<br>
end tell<br>
<br>
-- talk to the first terminal<br>
tell the first terminal<br>
<br>
-- launch a default shell in a new tab in the same terminal<br>
launch session "Default Session"<br>
<br>
tell the last session<br>
<br>
-- write some text<br>
write text "cd Projects/Cocoa/iTerm"<br>
-- write the contents of a file<br>
write contents of file "/path/to/file/"<br>
<br>
end tell<br>
<br>
end tell<br>
<br>
-- reposition window and name it<br>
set the bounds of the first window to {100, 100, 700, 700}<br>
set the name of the first window to "A Window Title"<br>
<br>
<br>
end tell<br>
</pre>

# Example of selecting a session by name #
This finds and selects a tab named "Special".

<pre>
tell application "iTerm"<br>
activate<br>
set myterm to (current terminal)<br>
tell myterm<br>
repeat with mysession in sessions<br>
tell mysession<br>
set the_name to get name<br>
if the_name contains "Special" then<br>
select mysession<br>
return<br>
end if<br>
end tell<br>
end repeat<br>
end tell<br>
end tell<br>
</pre>

# Open tabs to various machines #
<pre>
(* set to the user of the box, ie "root" or "deployer" *)<br>
set box_user to "user"<br>
(* Add the hostnames or IP's of the boxes to connect to. As many as you need. *)<br>
set my_boxes to {"box1", "box2", "box3"}<br>
<br>
tell application "iTerm"<br>
activate<br>
set t to (make new terminal)<br>
tell t<br>
(* Loop over the boxes, create a new tab and connect. *)<br>
repeat with box in my_boxes<br>
activate current session<br>
launch session "Default Session"<br>
tell the last session<br>
set conn to "ssh " & box_user & "@" & box<br>
write text conn<br>
end tell<br>
end repeat<br>
end tell<br>
end tell<br>
</pre>