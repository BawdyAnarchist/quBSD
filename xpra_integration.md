
### UPGRADES

High CPU usage
	- Show commands being used
	- Perhaps the log?
	- I did isolate and I did use the right env with xpra control
		- It does settle down, and it seems like probably --mmap=DIRECTORY helped the CPU usage (no record of it in the log), altho maybe it was --desktop-scaling=auto
		- Also, videos start to skip badly if I move the focus away from the screen
	- i3wm, FreeBSD 14.0

Screen blanking when on the console (no X11 started on host)

Delayed keystrokes telegram-desktop until I try to copy an image. Cant click on a full screen image, is blank.
	- okay it gets fixed it looks like with any copy operation
	- Happens no matter what. When specifying the socket-dir or socket file. With good start or bad start. 

Not honoring --notificiations=no --tray=no
Appears to not honor --pulseaudio=no 
Not removing old sockets inside of jails with xpra clean-sockets and clean-display

Clipboard only works with --socket-dir= ... not socket. What other env things could be being screwed up? 


SOLUTIONS WATCH
	--opengl=force
	--mmap=yes|ABSOLUTEFILENAME|DIRECTORY
	--desktop-scaling=auto
	--speaker=off
	--dbus ?
	--mmap-group=socket?
	--border ... might be able to implement border colors for security classification
	--title  ... might be able to set window titles


GUI SECURITY 
## I'M GETTING MASSIVE CPU USAGE, and often delays inside apps. NEED TO TROUBLESHOOT
 - Testing - see if you can start xcalc in jail on console, an if it pops up on starty
 - Need to clean old xpra sessions from jails on shutdown or something. I think that caused problems?
	- Need to create a check in qb-cmd that the xpra is attached if it's an xpra jail 
	- Gonna have to figure out a new way of assessing the jail'd status of a window
