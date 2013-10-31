#!/usr/bin/env sh

# Set Environment Variables
export HUBOT_IRC_NICK=slimer
export HUBOT_IRC_SERVER=irc.freenode.net
export HUBOT_IRC_ROOMS="#ghost,#Ghost-VIP,#Ghost-Dev underground"
export HUBOT_AUTH_ADMIN="jgable"
export HUBOT_HOSTNAME="ec2-54-227-53-105.compute-1.amazonaws.com:8008"

# Using SSL?
#export HUBOT_IRC_PORT=6697
#export HUBOT_IRC_USESSL=true
#export HUBOT_IRC_SERVER_FAKE_SSL=true

# Server password?
#export HUBOT_IRC_PASSWORD=password

# Don't let hubot flood the room.
export HUBOT_IRC_UNFLOOD=true

# Output environment variables
echo HUBOT_IRC_NICK=$HUBOT_IRC_NICK
echo HUBOT_IRC_SERVER=$HUBOT_IRC_SERVER
echo HUBOT_IRC_ROOMS=$HUBOT_IRC_ROOMS

#echo HUBOT_IRC_PORT=$HUBOT_IRC_PORT
#echo HUBOT_IRC_USESSL=$HUBOT_IRC_USESSL
#echo HUBOT_IRC_SERVER_FAKE_SSL=$HUBOT_IRC_SERVER_FAKE_SSL
#echo HUBOT_IRC_PASSWORD=$HUBOT_IRC_PASSWORD

# Start the redis brain
#echo ""
#echo "Starting Redis Server"
#/usr/local/bin/redis-server > /dev/null &

echo ""
echo "Starting bot"
PORT=8008 /home/ubuntu/slimer/bin/hubot -a irc
