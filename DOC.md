KANIVIS
Knowles Audible Navigation for Visually Impaired Sailors

Introduction

KANIVIS is a smartphone application designed to help blind and visually impaired sailors with the process of sailing and navigating a boat.  It connects to the boat's data bus that carries information
from the boat's instruments, and then reads aloud on-demand various
data concerning the boat's navigation. It beeps to indicate a material
change in depth. It can be set to generate audible beeps to indicate
that the boat is off-course.

The interface to the application is a grid of large buttons designed to
present an easy to use and intuitive system. There is audible feedback to
all operations.

General points

Please note that the application is entirely "read only", that is, it
will never cause any change to the operation of the boat.  So, for
example, the various steering functions change only the application's
notion of a target course or wind angle; this will in turn possibly
change the off-course alarms, but it will not impact, ever, the
operation of an autopilot or the rest of the boat's navigation.

The application is only as good as the boat's data bus. If the boat's
bus does not provide, for example, TWA, then nor will KANIVIS. KANIVIS
makes no attempt to calculate any values - it only records and relays
data received from the NMEA bus.

Initial configuration

The only operation required to initialise the application is to define
the endpoint to which the application should connect in order to
receive the boat's data. This configuration needs to be done once
only, and will only change if the boat's nav system changes or the
user is aboard a different boat. Values are stored, and recalled next
time the app is started.

This element alone might require the assistance of a sighted person
with access to, or knowledge of, the boat's data systems,

This short document does not attempt to detail the many possible ways
to connect to a boat's data bus, only to present a typical
example. Let us assume that the boat has a system that has a WiFi
access point called MyBoat.  First connect your smartphone to the
MyBoat access point.  With this complete, you must ascertain the IP
address and port number of the NMEA0183 data stream.  The IP address
might be, for example, 192.168.0.10; the port number is often
10110. Open KANIVIS, and use the so-called "hamburger menu" button in
the top bar of the application to reveal a "connection" option. Select
this, and enter the IP address (or name) and port number, as
discovered above.  Tap the Submit button, and you're done.  The main
KANIVIS screen is now visible and ready to use, and you are in command mode.

Command mode

The application starts in Command Mode. This comprises a grid of buttons in
3 columns of 5 rows. It is perhaps simplest to think of the buttons
from top to bottom as the digits on a phone dialler, with a fourth row
reading

 *  0  £

and a fifth row reading

-  Enter +

The functions of the buttons are as follows, detailed explanations follow.

1: Announce Apparent Wind
2: Announce True Wind
3: No function currently assigned
4: Announce Position
5: Announce Time (UTC)
6: Announce Waypoint information
7: Announce Heading
8: Announce Speed
9: Announce Trip
*: Set or switch steering mode: compass or wind, explained below
0: Announce Depth
£: Switch to number mode
-: Port 10 if steering to compass, or Bear Away 10 if steering to wind
Enter: Switch to Options mode
+: Starboard 10 if steering to compass, or Luff Up 10 if steering to wind.

Most of the functions are self-explanatory, or will be as soon as they
are tried; but some require further explanation.

Setting a course

When a course has been set, KANIVIS will give an audible warning akin
to a parking sensor,
indicating that the boat is off course and so enabling the helmsman to adjust
to bring the yacht back on course. The tone of the beeps is lower or
higher depending on whether the boat is to port or to starboard of its
intended course.  The frequency of the beeps increases the more the
boat is off course; up to 10 degrees off course there is no warning,
between 10 and 30 degrees there is an increasing beep rate; over 30
degrees the beep rate is consistent and fast.


We now examine the ways in which the target course can be set; there
are many!

Firstly, the application may be set to steer to an apparent wind
angle, or to a compass course.  When the steer button is pressed for
the first time, it will start tracking at the current compass course.
If the steer button is pressed again, it will switch to tracking the
current apparent wind angle. A further press will revert to compass
mode.

If a new course has been indicated by the navigator, it is often
useful to press the steer button twice in quick succession, which has
the effect of resetting the current compass or wind-angle being
tracked to match the boats current direction.

The tracked angle can be increased or decreased by ten degrees by
pressing the Port or Starboard buttons.

If you are steering to wind, then the Port 10 and Starboard 10 button
change meaning slightly to mean Bear Away or Luff Up, respectively.

To enter a specific compass course, or a specific wind angle, you must
be in either steer-to-compass or steer-to-wind mode. The only time you
will not be in one or the other mode is when the application is first
started.  Once the Steer button has been pressed one or more times,
you will be alternately in either compass or wind mode. To set and
explicit angle to track, press the Number button, which moves to
Number entry mode.  KANIVIS announces that the system is in Number
mode, and then an absolute or relative number may be entered using the
buttons on the screen with the usual phone-dialler positions.  A
relative number is entered using the + or - keys on the left and right
of the fifth row before entering the number. Numbers must be less than
360; if you attempt to enter a number greater than this, it will
cancel number entry and return to Command mode. If you specifically
want to cancel number entry mode, you can either deliberately enter an
excessively large number, or you can press the £ key.

If you have correctly entered the number you want, then press Enter to
have it accepted and applied.

Let's consider a series of illustrative examples.  You are currently
steering to a compass course of 320 degrees. The navigator indicates
that she would like to move to a heading of 305 degrees.  You press

 Number 3 0 5 Enter

Later, the navigator asks you to steer 10 degrees to starboard.  Press
Starboard.  Then the navigator asks you to ignore the compass and
maintain this wind angle.  You press the Steer button which switches
to Wind mode, setting the target angle to be the currently observed
angle. A little while later there is a wind shift and the navigator
asks you to luff up 10 degrees: you press the Stbd button.  Recall
that in wind mode, the Stbd button is interpreted to mean luff up
(reduce the AWA), and the Port button means bear away (increase AWA).

Options mode

To enter options mode press the enter key at the centre of the bottom
row. When you are in Options mode the screen is still divided into
three columns as usual. Button 1 gives a short description of the
functions of each of the buttons active in options mode.  To leave
Options mode, and save any changes you may have made, press the enter
key a second time which takes tyou back to Command mode.

The center and right hand columns are, respectively the Reduce and
Increase buttons, with the rows being, from top to bottom:

 Pitch
 Speech Speed
 Speech Volume
 Sensitivity

Pitch, speed, and volume are self-explanatory.
Sensitivy governs the rate of beep increase as the boat moves away
from its intended course or wind angle.  Higher sensitivities will
cause the beeps to accelerate sooner; lower sensitivities more slowly.

Other features

KANIVIS will provide an audible up-chirp, or down-chirp if the
reported depth changes by more than 10% of its previously chirped (or
spoken) value.

The depth chirps can be disabled and enabled using a long press on the
Depth button.

