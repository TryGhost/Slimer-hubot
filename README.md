Slimer
======

[Ghost's](https://github.com/TryGhost/Ghost) IRC bot based on [Hubot](http://hubot.github.com).

## Custom Scripts

- [Logger](https://github.com/TryGhost/Slimer/blob/master/scripts/logger.coffee)
- [Ghost Issues](https://github.com/TryGhost/Slimer/blob/master/scripts/ghost-issues.coffee)
- [Ghost Milestones](https://github.com/TryGhost/Slimer/blob/master/scripts/ghost-milestones.coffee)
- [Ghost Roadmap](https://github.com/TryGhost/Slimer/blob/master/scripts/ghost-roadmap.coffee)

## Running Locally

To get a version of the bot running locally clone the repo down and run the [runlocal.sh](https://github.com/TryGhost/Slimer/blob/master/runlocal.sh) shell script; e.g. `. runlocal.sh` from the project root.  **NOTE**: You need to have a redis server running (`redis-server &` should do the trick for starting it in a background thread).

This will start a bot named `slimer-test` that will join `#ghost-slimer-test` on irc.freenode.net but you can modify your runlocal.sh if you want to change it.

## Copyright & License

Copyright (c) 2013-2018 Ghost Foundation - Released under the [MIT license](LICENSE).
