# Description:
#   Logs chat to Redis and displays it over HTTP
#
# Dependencies:
#   "redis": ">=0.7.2"
#   "moment": ">=1.7.0"
#
# Configuration:
#   LOG_REDIS_URL: URL to Redis backend to use for logging (uses REDISTOGO_URL 
#                  if unset, and localhost:6379 if that is unset.
#   LOG_HTTP_USER: username for viewing logs over HTTP (default 'logs' if unset)
#   LOG_HTTP_PASS: password for viewing logs over HTTP (default 'changeme' if unset)
#   LOG_HTTP_PORT: port for our logging Connect server to listen on (default 8081)
#   LOG_STEALTH:   If set, bot will not announce that it is logging in chat
#   LOG_MESSAGES_ONLY: If set, bot will not log room enter or leave events
#
# Commands:
#   hubot logs - show the url where you can view the logs for today
#   hubot send me today's logs - messages you the logs for today
#   hubot what did I miss - messages you logs for the past 10 minutes
#   hubot what did I miss in the last x seconds/minutes/hours - messages you logs for the past x
#   hubot start logging - start logging messages from now on
#
# Notes:
#   This script by default starts a Connect server on 8081 with the following routes:
#     /
#       Form that takes a room ID and two UNIX timestamps to show the logs between.
#       Action is a GET with room, start, and end parameters to /logs/view.
#
#     /logs/view?room=room_name&start=1234567890&end=1456789023&presence=true
#       Shows logs between UNIX timestamps <start> and <end> for <room>,
#       and includes presence changes (joins, parts) if <presence>
#
#     /logs/:room
#       Lists all logs in the database for <room>
#
#     /logs/:room/YYYMMDD?presence=true
#       Lists all logs in <room> for the date YYYYMMDD, and includes joins and parts
#       if <presence>
#
#   Feel free to edit the HTML views at the bottom of this module if you want to make the views
#   prettier or more functional.
#
#   I have only thoroughly tested this script with the xmpp and shell adapters. It doesn't use
#   anything that necessarily wouldn't work with other adapters, but it's possible some adapters
#   may have issues sending large amounts of logs in a single message.
#
# Author:
#   jenrzzz


Redis = require "redis"
Url   = require "url"
Util  = require "util"
moment = require "moment"
hubot = require "hubot"

# Convenience class to represent a log entry
class Entry
 constructor: (@from, @timestamp, @type='text', @message='') ->

redis_server = Url.parse process.env.LOG_REDIS_URL || process.env.REDISTOGO_URL || 'redis://localhost:6379'

module.exports = (robot) ->
  robot.logging ||= {} # stores some state info that should not persist between application runs
  robot.brain.data.logging ||= {}
  robot.logger.debug "Starting chat logger."

  # Setup our own redis connection
  client = Redis.createClient redis_server.port, redis_server.hostname
  if redis_server.auth
    client.auth redis_server.auth.split(":")[1]
  client.on 'error', (err) ->
    robot.logger.error "Chat logger was unable to connect to a Redis backend at #{redis_server.hostname}:#{redis_server.port}"
    robot.logger.error err
  client.on 'connect', ->
    robot.logger.debug "Chat logger successfully connected to Redis."

  # Add a listener that matches all messages and calls log_message with redis and robot instances and a Response object
  robot.listeners.push new hubot.Listener(robot, ((msg) -> return true), (res) -> log_message(client, robot, res))

  # Override send methods in the Response prototype so that we can log Hubot's replies
  # This is kind of evil, but there doesn't appear to be a better way
  log_response = (room, strings...) ->
    return unless robot.brain.data.logging[room]?.enabled
    for string in strings
      log_entry client, (new Entry(robot.name, Date.now(), 'text', string)), room

  response_orig =
    send: robot.Response.prototype.send
    reply: robot.Response.prototype.reply

  robot.Response.prototype.send = (strings...) ->
    log_response @message.user.room, strings...
    response_orig.send.call @, strings...

  robot.Response.prototype.reply = (strings...) ->
    log_response @message.user.room, strings...
    response_orig.reply.call @, strings...

  ####################
  ## HTTP interface ##
  ####################

  if robot.router
    app = robot.router
    app.get '/', (req, res) ->
      res.statusCode = 200
      res.setHeader 'Content-Type', 'text/html'
      res.end views.index

    app.get '/logs/view', (req, res) ->
      res.statusCode = 200
      res.setHeader 'Content-Type', 'text/html'
      if not (req.query.start || req.query.end)
        res.end '<strong>No start or end date provided</strong>'
      m_start = parseInt(req.query.start)
      m_end   = parseInt(req.query.end)
      if isNaN(m_start) or isNaN(m_end)
        res.end "Invalid range"
        return
      m_start = moment.unix m_start
      m_end   = moment.unix m_end
      room = req.query.room || 'general'
      presence = !!req.query.presence
      get_logs_for_range client, m_start, m_end, room, (replies) ->
        res.write views.log_view.head
        res.write format_logs_for_html(replies, presence).join("\r\n")
        res.end views.log_view.tail

    app.get '/logs/:room', (req, res) ->
      res.statusCode = 200
      res.setHeader 'Content-Type', 'text/html'
      res.write views.log_view.head
      res.write "<h2>Logs for #{req.params.room}</h2>\r\n"
      res.write "<ul>\r\n"

      # This is a bit of a hack... KEYS takes O(n) time
      # and shouldn't be used for this, but it's not worth
      # creating a set just so that we can list all logs 
      # for a room.
      client.keys "logs:#{req.params.room}:*", (err, replies) ->
        days = []
        for key in replies
          key = key.slice key.lastIndexOf(':')+1, key.length
          days.push moment(key, "YYYYMMDD")
        days.sort (a, b) ->
            return b.diff(a)
        days.forEach (date) ->
          res.write "<li><a href=\"/logs/#{encodeURIComponent(req.params.room)}/#{date.format('YYYYMMDD')}\">#{date.format('dddd, MMMM Do YYYY')}</a></li>\r\n"
        res.write "</ul>"
        res.end views.log_view.tail

    app.get '/logs/:room/:id', (req, res) ->
      res.statusCode = 200
      res.setHeader 'Content-Type', 'text/html'
      presence = !!req.query.presence
      id = parseInt req.params.id
      if isNaN(id)
        res.end "Bad log ID"
        return
      get_log client, req.params.room, id, (logs) ->
        res.write views.log_view.head
        res.write format_logs_for_html(logs, presence).join("\r\n")
        res.end views.log_view.tail

  ####################
  ## Chat interface ##
  ####################

  # When we join a room, wait for some activity and notify that we're logging chat
  # unless we're in stealth mode
  robot.hear /.*/, (msg) ->
    room = msg.message.user.room
    robot.logging[room] ||= {}
    robot.brain.data.logging[room] ||= {}
    if msg.match[0].match(///(#{robot.name} )?(start|stop) logging*///) or process.env.LOG_STEALTH
      robot.logging[room].notified = true
      return
    if robot.brain.data.logging[room].enabled and not robot.logging[room].notified
      msg.send "I'm logging messages in #{room} at " +
                 "http://#{process.env.HUBOT_HOSTNAME}/" +
                 "logs/#{encodeURIComponent(room)}/#{date_id()}\n"
      robot.logging[room].notified = true

  # Give current logs url
  robot.respond /logs$/i, (msg) ->
    msg.send "Logs for this room can be found at: http://#{process.env.HUBOT_HOSTNAME}/logs/#{encodeURIComponent(msg.message.user.room)}/#{date_id()}"

  # Enable logging
  robot.respond /start logging( messages)?$/i, (msg) ->
    enable_logging robot, client, msg

  # PM logs to people who request them
  robot.respond /(message|send) me (all|the|today'?s) logs?$/i, (msg) ->
    get_logs_for_day client, new Date(), msg.message.user.room, (logs) ->
      if logs.length == 0
        msg.reply "I don't have any logs saved for today."
        return

      logs_formatted = format_logs_for_chat(logs)
      robot.send direct_user(msg.message.user.id, msg.message.user.room), logs_formatted.join("\n")

  robot.respond /what did I miss\??$/i, (msg) ->
    now = moment()
    before = moment().subtract('m', 10)
    get_logs_for_range client, before, now, msg.message.user.room, (logs) ->
      logs_formatted = format_logs_for_chat(logs)
      robot.send direct_user(msg.message.user.id, msg.message.user.room), logs_formatted.join("\n")

  robot.respond /what did I miss in the [pl]ast ([0-9]+) (seconds?|minutes?|hours?)\??/i, (msg) ->
    num = parseInt(msg.match[1])
    if isNaN(num)
      msg.reply "I'm not sure how much time #{msg.match[1]} #{msg.match[2]} refers to."
      return
    now   = moment()
    start = moment().subtract(msg.match[2][0], num)

    if now.diff(start, 'days', true) > 1
      robot.send direct_user(msg.message.user.id, msg.message.user.room),
                 "I can only tell you activity for the last 24 hours in a message."
      start = now.sod().subtract('d', 1)

    get_logs_for_range client, start, moment(), msg.message.user.room, (logs) ->
      logs_formatted = format_logs_for_chat(logs)
      robot.send direct_user(msg.message.user.id, msg.message.user.room), logs_formatted.join("\n")


####################
##    Helpers     ##
####################

# Converts date into a string formatted YYYYMMDD
date_id = (date=moment())->
  date = moment(date) if date instanceof Date
  return date.format("YYYYMMDD")

# Returns an array of date IDs for the range between
# start and end (inclusive)
enumerate_keys_for_date_range = (start, end) ->
  ids = []
  start = moment(start) if start instanceof Date
  end = moment(end) if end instanceof Date
  start_i = moment(start)
  while end.diff(start_i, 'days', true) >= 0
    ids.push date_id(start_i)
    start_i.add 'days', 1
  return ids

# Returns an array of pretty-printed log messages for <logs>
# Params:
#   logs - an array of log objects
format_logs_for_chat = (logs) ->
  formatted = []
  logs.forEach (item) ->
    entry = JSON.parse item
    timestamp = moment(entry.timestamp)
    str = timestamp.format("MMM DD YYYY HH:mm:ss")

    if entry.type is 'join'
      str += " #{entry.from} joined"
    else if entry.type is 'part'
      str += " #{entry.from} left"
    else
      str += " <#{entry.from}> #{entry.message}"
    formatted.push str
  return formatted

# Returns a string that is half heartedly html encoded for display
htmlEntities = (str) ->
    String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

# Returns an array of lines representing a table for <logs>
# Params:
#   logs - an array of log objects
format_logs_for_html = (logs, presence=true) ->
  lines = []
  last_entry = null
  for log in logs
    l = JSON.parse log

    # Don't print a bunch of join or part messages for the same person. Hubot sometimes
    # sees keepalives from Jabber gateways as multiple joins
    continue if l.type != 'text' and l.from == last_entry?.from and l.type == last_entry?.type
    continue if not presence and l.type != 'text'
    l.date = moment(l.timestamp)

    # If the date changed
    if not (l.date.date() == last_entry?.date?.date() and l.date.month() == last_entry?.date?.month())
      lines.push """<div class="row logentry">
                  <div class="span2">&nbsp;</div>
                  <div class="span10"><strong>Date changed to #{l.date.format("D MMMM YYYY")}</strong></div>
                </div>
              """
    last_entry = l
    l.time = moment(l.timestamp).format("h:mm:ss a")
    l.datetime = moment(l.timestamp).format("MM-DD-YYYY h:mm:ss a")
    l.timeid = moment(l.timestamp).format("ahmmss")
    switch l.type
      when 'join'
        lines.push """<div class="row logentry">
                        <div class="span2">
                          <time id="#{l.timeid}" datetime="#{l.datetime}">#{l.time}</time>
                        </div>
                        <div class="span10">
                          <p><span class="username">#{l.from}</span> joined</p>
                        </div>
                      </div>
                    """
      when 'part'
         lines.push """<div class="row logentry">
                        <div class="span2">
                          <time id="#{l.timeid}" datetime="#{l.datetime}">#{l.time}</time>
                        </div>
                        <div class="span10">
                          <p><span class="username">#{l.from}</span> left</p>
                        </div>
                      </div>
                    """
      when 'text'
         lines.push """<div class="row logentry">
                        <div class="span2">
                          <time id="#{l.timeid}" datetime="#{l.datetime}">#{l.time}</time>
                        </div>
                        <div class="span10">
                          <p>&lt;<span class="username">#{l.from}</span>&gt;&nbsp;#{htmlEntities(l.message)}</p>
                        </div>
                      </div>
                   """
  return lines

# Returns a User object to send a direct message to
# Params:
#   id   - the user's adapter ID
#   room - string representing the room the user is in (optional for some adapters)
direct_user = (id, room=null) ->
  u =
    type: 'direct'
    id: id
    room: room

# Calls back an array of JSON log objects representing the log
# for the given ID
# Params:
#   redis - a Redis client object
#   room  - the room to look up logs for
#   id    - the date to look up logs for
#   callback - a function that takes an array
get_log = (redis, room, id, callback) ->
  log_key = "logs:#{room}:#{id}"
  return [] if not redis.exists log_key
  redis.lrange [log_key, 0, -1], (err, replies) ->
    callback(replies)

# Calls back an array of JSON log objects representing the log
# for every date ID in <ids>
# Params:
#   redis - a Redis client object
#   room  - the room to look up logs for
#   ids   - an array of YYYYMMDD date id strings to pull logs for
#   callback - a function taking an array of log objects
get_logs_for_array = (redis, room, ids, callback) ->
  m = redis.multi()
  for id in ids
    m.lrange("logs:#{room}:#{id}", 0, -1)
  m.exec (err, reply) ->
    ret = []
    if reply[0] instanceof Array
      for r in reply
        ret = ret.concat r
    else
      ret = reply
    callback(ret)

# Calls back an array of JSON log objects representing the log
# for <date>
# Params:
#   redis - a Redis client object
#   date  - Date or Moment object representing the date to look up
#   room  - the room to look up 
#   callback - function to pass an array of log objects for date to
get_logs_for_day = (redis, date, room, callback) ->
  get_log redis, room, date_id(date), (reply) ->
    callback(reply)

# Calls back an array of JSON log objects representing the log
# between <start> and <end>
# Params:
#   redis  - a Redis client object
#   start  - Date or Moment object representing the start of the range
#   end    - Date or Moment object representing the end of the range (inclusive)
#   room   - the room to look up logs for
#   callback - a function taking an array as an argument
get_logs_for_range = (redis, start, end, room, callback) ->
  get_logs_for_array redis, room, enumerate_keys_for_date_range(start, end), (logs) ->
    # TODO: use a fuzzy binary search to find the start and end indices
    # of the log entries we want instead of iterating through the whole thing
    slice = []
    for log in logs
      e = JSON.parse log
      slice.push log if e.timestamp >= start.valueOf() && e.timestamp <= end.valueOf()
    callback(slice)

# Enables logging for the room that sent response
# Params:
#   robot - a Robot instance
#   redis - a Redis client object
#   response - a Response that can be replied to
enable_logging = (robot, redis, response) ->
  robot.brain.data.logging[response.message.user.room] ||= {}
  if robot.brain.data.logging[response.message.user.room].enabled
    response.reply "Logging is already enabled."
    return
  robot.brain.data.logging[response.message.user.room].enabled = true
  robot.brain.data.logging[response.message.user.room].pause = null

  room = response.message.user.room || response.message.user.name || "unknown"

  log_entry(redis, new Entry(robot.name, Date.now(), 'text',
            "#{response.message.user.name || response.message.user.id} restarted logging."),
            room)

  response.reply "I will log messages in #{room} at " +
                 "http://#{process.env.HUBOT_HOSTNAME}/" +
                 "logs/#{encodeURIComponent(room)}/#{date_id()} from now on.\n" +
                 "Say `#{robot.name} stop logging forever' to disable logging indefinitely."
  robot.brain.save()

# Disables logging for the room that sent response
# Params:
#   robot - a Robot instance
#   redis - a Redis client object
#   response - a Response that can be replied to
#   end - a Moment representing the time at which to start logging again, or
#       - a number representing the number of milliseconds until logging should be resumed, or
#       - 0 or undefined to disable logging indefinitely
disable_logging = (robot, redis, response, end=0) ->
  room = response.message.user.room
  robot.brain.data.logging[room] ||= {}

  # If logging was already disabled
  if robot.brain.data.logging[room].enabled == false
    if robot.brain.data.logging[room].pause
      pause = robot.brain.data.logging[room].pause
      if pause.time and pause.end and end and end != 0
        response.reply "Logging was already disabled #{pause.time.fromNow()} by " +
                       "#{pause.user} until #{pause.end.format()}."
      else
        robot.brain.data.logging[room].pause = null
        response.reply "Logging is currently disabled."
    else
      response.reply "Logging is currently disabled."
    return

  # Otherwise, disable it
  robot.brain.data.logging[room].enabled = false
  if end != 0
    if not end instanceof moment
      if end instanceof Date
        end = moment(end)
      else
        end = moment().add('seconds', parseInt(end))
    robot.brain.data.logging[room].pause =
      time: moment()
      user: response.message.user.name || response.message.user.id || 'unknown'
      end: end
    log_entry(redis, new Entry(robot.name, Date.now(), 'text',
              "#{response.message.user.name || response.message.user.id} disabled logging" +
              " until #{end.format()}."), room)

    # Re-enable logging after the set amount of time
    setTimeout (-> enable_logging(robot, redis, response) if not robot.brain.data.logging[room].enabled),
                  end.diff(moment())
    response.reply "OK, I'll stop logging until #{end.format()}."
    robot.brain.save()
    return
  log_entry(redis, new Entry(robot.name, Date.now(), 'text',
            "#{response.message.user.name || response.message.user.id} disabled logging indefinitely."), 
            room)

  robot.brain.save()
  response.reply "OK, I'll stop logging from now on."

# Logs an Entry object
# Params:
#   redis - a Redis client instance
#   entry - an Entry object to log
#   room  - the room to log it in
log_entry = (redis, entry, room='general') ->
  if not entry.type && entry.timestamp
    throw new Error("Argument #{entry} to log_entry is not an entry object")
  entry = JSON.stringify entry
  redis.rpush("logs:#{room}:#{date_id()}", entry)

# Listener callback to log message in redis
# Params:
#   redis - a Redis client instance
#   response - a Response object emitted from a Listener
log_message = (redis, robot, response) ->
  return if not robot.brain.data.logging[response.message.user.room]?.enabled
  if response.message instanceof hubot.TextMessage
    type = 'text'
  else if response.message instanceof hubot.EnterMessage
    type = 'join'
  else if response.message instanceof hubot.LeaveMessage
    type = 'part'
  return if process.env.LOG_MESSAGES_ONLY && type != 'text'

  userName = response.message.user?.name || response.message.user?['id']
  entry = JSON.stringify(new Entry(userName, Date.now(), type, response.message.text))
  room = response.message.user.room || 'general'
  redis.rpush("logs:#{room}:#{date_id()}", entry)


####################
##     Views      ##
####################

views =
  index: """
    <!DOCTYPE html>
    <html>
      <head>
        <title>View logs</title>
        <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" rel="stylesheet">
      </head>
      <body>
        <div class="container">
          <div class="row">
            <div class="span8">
              <form action="/logs/view" class="form-vertical" method="get">
              <fieldset>
                <legend>Search for logs</legend>
                <label for="room">JID of room</label>
                <input name="room" type="text" placeholder="chatroom@conference.jabber.example.com"><br />
                <label for="start">UNIX timestamp for start date</label>
                <input name="start" type="text" placeholder="1234567890" />
                <label for="end">End date</label>
                <input name="end" type="text" placeholder="1234567890" />
                <span><label for="presence">Show joins and parts?</label>
                <input name="presence" type="checkbox" /></span><br /><br />
                <button type="submit" class="btn">Submit</button>
              </fieldset>
              </form>
            </div>
          </div>
        </div>
      </body>
    </html>"""
  log_view:
    head: """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Viewing logs</title>
          <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" rel="stylesheet">
          <style type="text/css">
            .logentry {
              font-family: Consolas, Inconsolata, monospace;
            }
            .username {
              color: blue;
              font-weight: bold;
            }
          </style>
        </head>
        <body>
          <div class="container">
        """
    tail: "</div></body></html>"

