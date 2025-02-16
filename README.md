# UGVR_game_profiles
 Website to host game config profiles for the Universal Godot VR Injector (UGVR)


## What is UGVR?

UGVR aims to add basic virtual reality functionality to 3D games made in the Godot Game Engine (Godot 4.x). You can learn more about it here: https://github.com/teddybear082/UGVR, and the Wiki here: https://github.com/teddybear082/UGVR/wiki

## What are these files?

UGVR works by dropping its VR injector files into your game directory.  This website will host versions of UGVR with configiration files that either I or someome else has personally manually configred and tested.  Some will have custom code built in for games, or certain special options turned on.  You can still manually edit any of the configuration files but the aim is for files here to be "a great start with X game."

## How do I use these files?

The site itself will contain underlying source code of each set of files so I can track changes over time, but most users should probably just head to the **releases** page (https://github.com/teddybear082/UGVR_game_profiles/releases), find the game they are interested in playing in VR and download the release for it.  

Each release will include **all UGVR files needed for each game**, so the goal is that people who just want to play don't really have to touch the underlying UGVR github page.

Just **download the release for the game you want to play**, and **unzip** the contents as **loose files** into the folder where the game is installed (e.g. where the game .exe file is).  Then start the game and it should launch in VR if your headset is active and running.  In Steam, you can find where the game is installed by clicking the settings wheel by the game, then manage and then browse local files.

## How do I go back to playing my game in flatscreen mode?

Just rename **override.cfg** to anything else, for example no-override.cfg.  Then the injector won't inject.  Rename back to override.cfg to play in VR again.

## Why isn't the game launching in VR?

Common reasons are:

(1) Your headset wasnt on and active when you started the game.  Close the game, make sure your headset is active and try again.

(2) You have OpenXR toolkit installed (by MBucchia).  Uninstall it, or deactivate it, or create an exception for all Godot games you want to run.

(3) Your OpenXR runtime is not set up properly.  Use VDXR with Virtual Desktop, use SteamVR OpenXR for WMR (and probably Pico), use Meta OpenXR for Airlink or Link.

Enjoy!
