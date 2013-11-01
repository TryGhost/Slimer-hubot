# Description:
#   Utility commands surrounding Hubot uptime.
#
# Commands:
#   hubot ping - Reply with pong
#   hubot echo <text> - Reply back with <text>
#   hubot time - Reply with current time
#   hubot die - End hubot process

adminRegexes = [
  /^JohnONolan$/,
  /^HannahWolfe$/,
  /^jgable$/
]

module.exports = (robot) ->
  robot.respond /PING$/i, (msg) ->
    msg.send "PONG"

  robot.respond /ECHO (.*)$/i, (msg) ->
    msg.send msg.match[1]

  robot.respond /TIME$/i, (msg) ->
    msg.send "Server time is: #{new Date()}"

  robot.respond /DIE$/i, (response) ->
    
    for adminReg in adminRegexes when response.message?.user?.name?.match(adminReg)
      response.send "Goodbye, cruel world."
      setTimeout (-> process.exit 0), 1000

    response.send "Ah ah ah, you didn't say the magic word."
