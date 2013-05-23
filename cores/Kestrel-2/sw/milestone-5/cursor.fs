\ Dependencies:
\
\ #ch/row ( -- n )	This word gives the number of characters on a single row.
\ #rows ( -- n )  This word gives the usable number of rows on the screen.
\
\ x ( -- a )	this variable contains the horizontal component of a coordinate pair.
\ y ( -- a )	this variable contains the vertical component of a coordinate pair.
\				Both x and y must conform to the following invariants:
\
\				(0 <= x < #ch/row) /\ (0 <= y < #rows)

' #ch/row >body @ 1- const, #ch/row-1
' #rows >body @ 1- const, #rows-1

\ hidden indicates whether or not the cursor is "hidden" from the user's view.
\ It is a proper counter; if zero, the cursor will be visible to the user.
\ Otherwise, not.
int, hidden

\ vis indicates if the _image_ of the cursor is visible to the user.
\ Note the distinction from the cursor as a whole.  A cursor may be visible
\ to the user, but the image at a given moment in time might not be (e.g., the
\ cursor might periodically reverse video).
\
\ Bit 0 indicates whether the image is currently visible to the user.
int, vis

\ hidden? returns true if the cursor is hidden from the user's view.
:, hidden?		hidden @, if, -1 #, exit, then, 0 #, ;,

\ visible? returns true only if the cursor image is visible to the user.
\ Valid only if hidden? returns false.
:, visible?		vis @, if, -1 #, exit, then, 0 #, ;,

\ invisible? returns true only if the cursor image is not visible to the user.
:, invisible?	visible? -1 #, xor, ;,

int, cx
int, cy
int, bx
int, by

\ getxy will return the cursor's current position (in x and y variables) on the screen.
:, getxy		cx @, x !,  cy @, y !, ;,

:, inverse		cx @, Left !,  cx @, 1 #, +, Right !,
				cy @, Top !,   cy @, 1 #, +, Bottom !,  ReverseVideo ;,

:, blink		vis @, 1 #, xor, vis !, inverse ;,
:, off			vis @, if, blink then, ;,

\ toggle alters the cursor image (reverse video to normal video, or
\ vice versa).  This procedure is typically called by a timer interrupt
\ handler.
:, toggle		hidden @, if, exit, then, blink ;,

\ hide will hide the cursor from the user's view, leaving the framebuffer in a
\ pristine state.  Note that hide and reveal nest; thus, this procedure doesn't
\ adjust a flag, but rather adjusts a counter.  The counter saturates at 65535.
:, hide			hidden @, -1 #, xor, if, hidden @, 1 #, +, hidden !, off then, ;,

\ reveal will show the cursor to the user.  Note that hide and reveal nest;
\ for every time the cursor is hidden, reveal must be invoked before the user
\ will actually see the cursor.  The hidden counter saturates at 0; thus,
\ even if you call reveal more times than hide has been invoked, it only takes
\ a single call to hide to hide the cursor again.
:, reveal		hidden @, if, hidden @, -1 #, +, hidden !, toggle then, ;,

\ redge moves the cursor to the far right-hand edge of the screen.  This word is useful
\ for unit-testing only.
:, redge		hide  #ch/row-1 cx !,  reveal ;,

\ REdge? returns true if the cursor sits on the right-hand edge of the screen.
:, REdge?		cx @, #ch/row-1 xor, if, 0 #, exit, then, -1 #, ;,

\ mvup moves the cursor up one line, if it can.
:, mvup			hide  cy @, if, cy @, -1 #, +, cy !, then,  reveal ;,

\ bookmark moves the current bookmark _up_ one line without scrolling it off the edge of the screen.
:, bookmark		by @, if, by @, -1 #, +, by !, then, ;,

\ mvdown moves the cursor down one line, if it can.
:, mvdown		hide  cy @, #rows-1 xor, if, cy @, 1 #, +, cy !,  reveal exit, then,  reveal bookmark ;,

\ return performs a carriage return.
:, return		hide  0 #, cx !,  reveal ;,

\ mvleft moves the cursor one place to the left, if it can.
:, mvleft		hide  cx @, if, cx @, -1 #, +, cx !,  reveal exit, then, cy @, if, mvup redge then,  reveal ;,

\ mvright moves the cursor one place to the right, if it can.
:, mvright		hide  cx @, #ch/row-1 xor, if, cx @, 1 #, +, cx !,  reveal exit, then, return mvdown  reveal ;,

\ bedge moves the cursor to the bottom of the screen.  This word is useful for unit-testing
\ only.
:, bedge		hide  #rows-1 cy !,  reveal ;,

\ BEdge? returns true if the cursor sits on the bottom edge of the screen.
:, BEdge?		cy @, #rows-1 xor, if, 0 #, exit, then, -1 #, ;,

\ home relocates the cursor to the upper-lefthand corner of the screen.
:, home			hide  0 #, cx !,  0 #, cy !,  reveal ;,

\ 0cursor resets the cursor subsystem to its default, power-on state.
\ To ensure the video framebuffer is synchronized with the expectations of the cursor
\ module, you should clear the screen either before or after calling 0cursor.
\ The cursor's hidden counter is set to one, meaning it takes only one call to
\ reveal to show the cursor.  It is also relocated to the home position on the
\ screen (0,0).
:, 0cursor		1 #, hidden !,  0 #, vis !, home ;,

\ setbm remembers the current cursor position in a bookmark.
\ The caller can use resetbm to reset the cursor position to the most recently bookmarked position.
\ If the screen scrolls, the bookmark scrolls with the screen.
\ However, the bookmark never falls off the top edge of the screen.
\ This allows, for instance, a line editor to support input text larger than the screen width despite
\ providing input near the bottom of the screen, where scrolling has a higher probability of happening.
:, setbm		cx @, bx !,  cy @, by !, ;,

\ resetbm restores the cursor to the most recently set bookmark position.
\ Use setbm to set the bookmark.
:, resetbm		bx @, cx !,  by @, cy !, ;,
