# Description:
#   Github utility commands for TryGhost/Ghost
#
# Commands:
#   hubot roadmap - Reply with link to roadmap

module.exports = (robot) ->
    robot.respond /roadmap/i, (response) ->
        roadmap = "https://trello.com/b/EceUgtCL/ghost-roadmap"
        plans = "https://github.com/TryGhost/Ghost/wiki/Planned-Features"
        response.send "Roadmap is at #{roadmap}, Future plans are at #{plans}"
