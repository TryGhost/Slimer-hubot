# Description:
#   Github utility commands for TryGhost/Ghost
#
# Commands:
#   ... milestone name - Reply with link to milestone
#   hubot milestone name - Reply with link to milestone

request = require 'request'

milestones = (user, repo) -> "https://api.github.com/repos/#{user}/#{repo}/milestones"

module.exports = (robot) ->
    robot.respond /milestone ([^\s]+)/i, (response) ->
        milestoneName = response.match[1]
        milestoneUrl = milestones "TryGhost", "Ghost"

        unless milestoneName
            console.log "Missing milestoneName: #{milestoneName}"
            return

        opts = 
            url: milestoneUrl
            headers: { 'User-Agent': 'Ghost Slimer' }
        
        request opts, (err, reqResp, body) ->
            if err
                console.log "Error getting milestone info: #{err.message}"
                return

            try
                ms = JSON.parse(body);
                milestoneList = ms.filter (obj) ->
                    return obj.title == milestoneName
                milestone = milestoneList.shift();
                return unless milestone

                title = milestone.title
                open = milestone.open_issues
                closed = milestone.closed_issues
                due = milestone.due_on 
                text = "Milestone #{title} (#{open} open/#{closed} closed issues)"
                if due
                    date = (new Date(due)).toDateString()
                    text += " is due on #{date}"
                else 
                    text += " has no due date"
                url = "https://github.com/TryGhost/Ghost/issues?milestone=#{milestone.number}&state=open"
                text += " (#{url})"

                response.send text
            catch err
                console.log "Failed to get milestone info: #{err.message}, #{body}"
