BRITANNIA REBORN - friends' test build
======================================

A private test build of a modern 3D client for Ultima Online, with its own
game server. Thank you for helping to test it!

Please do not pass this package on: it contains Ultima Online game data,
which belongs to Electronic Arts, and is shared only with our test group.


WHAT YOU NEED
-------------
- Windows 10 or 11, 64-bit.
- A graphics card from roughly the last 8 years (Vulkan support: any
  NVIDIA GTX 900 series / AMD RX 400 series / Intel Iris Xe or newer).
- 16 GB of memory recommended (8 GB works, more slowly).
- About 30 GB of free disk space (an SSD makes loading much faster).
- No internet connection is needed, and nothing needs installing.


INSTALL
-------
1. Right-click the zip file and choose "Extract All...". Pick a folder
   with plenty of space, for example C:\Games. Do NOT extract into
   "Program Files" (the game writes its settings next to itself).
   Extracting takes a few minutes.
2. Open the extracted "BritanniaReborn" folder.


START
-----
1. Double-click Play.cmd.
   - If Windows shows "Windows protected your PC", click "More info",
     then "Run anyway". (The package is not signed; it is safe.)
   - If Windows Firewall asks about "dotnet" or "Godot", you can click
     Cancel: everything runs on your own computer only.
2. A black window opens and starts the game server (the first time this
   takes a minute or two), then the game opens. Leave the black window
   open while you play.
3. Sign in with:
     Account:  {USERNAME}
     Password: {PASSWORD}
4. Choose the character "Tester" and enter the world.
   "Tester" is an administrator. You start in Britain; the whole of
   Trammel is there to explore, with towns, vendors, monsters, dungeons
   and moongates.

The first time you enter the world, the land around you takes a few
seconds to appear; after that it streams in as you walk.


PLAYING
-------
- W A S D walk, hold Shift to run, Space hops.
- Right mouse button: look around. Mouse wheel: zoom.
- Click things to use or pick them up; items you can take glow softly.
- Esc opens the game menu:
    Keys and help ............ every key and control
    Developer > Travel ....... go to any town, dungeon or shrine
    Developer > Die/Resurrect  try the ghost world
    Voice and translation .... optional (needs extra setup)
- Enter opens the chat line.


STOPPING
--------
Close the game window, then double-click Stop Server.cmd to stop the game
server. The world saves itself every few minutes, so your progress stays.
Next time, just double-click Play.cmd again.


IF SOMETHING GOES WRONG
-----------------------
- "The game server did not start": look at
  Server\runtime\server.log (the last lines say why) and send it to us.
  Make sure no other copy of the game or server is running, then try
  Play.cmd again.
- The game window is black or closes at once: update your graphics card
  driver and try again. If it still fails, send us the file
  .godot-user\Godot\app_userdata\UO World Studio\logs\godot.log
  (inside the BritanniaReborn folder).
- Very slow or stuttering: close other programs; an SSD and 16 GB of
  memory help a lot.
- "Cannot connect": start with Play.cmd (it starts the server first).


SENDING FEEDBACK
----------------
For anything that looks wrong or could be better, note:
- what you did and what you saw,
- where: the coordinates shown at the top of the screen,
- a screenshot (Windows key + Shift + S) if you can,
and send it to us. Every report helps. Have fun!
