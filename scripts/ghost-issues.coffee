# Description:
#   Github utility commands for TryGhost/Ghost
#
# Commands:
#   ... issue #1234 - Reply with link to issue
#   hubot issue TryGhost/Ghost#1234 - Reply with link to issue

request = require 'request'

urls = 
    repo: (user, repo) -> "https://api.github.com/repos/#{user}/#{repo}"
    issue: (user, repo, number) -> @repo(user, repo) + "/issues/#{number}"

module.exports = (robot) ->
    robot.hear /#([0-9]+)/, (response) ->
        issueNumber = response.match[1]
        issueUrl = urls.issue "TryGhost", "Ghost", issueNumber
        opts = 
            url: issueUrl
            headers: { 'User-Agent': 'Ghost Slimer' }
        
        request opts, (err, reqResp, body) ->
            return if err

            try
                issueInfo = JSON.parse body
                title = if issueInfo.title.length > 100 then issueInfo.title.slice(0, 97) + '...' else issueInfo.title
                response.send "[##{issueNumber}] #{title} (#{issueInfo.html_url})"
            catch e
                console.log "Failed to get issue info:", e.message
                console.log "Request:", issueUrl, body

    robot.respond /.*issue (\w+)\/(\w+)#([0-9]+).*/i, (response) ->
        user = response.match[1] || "TryGhost"
        repo = response.match[2] || "Ghost"
        issueNumber = response.match[3]
        issueUrl = urls.issue user, repo, issueNumber
         
        opts = 
            url: issueUrl
            headers: { 'User-Agent': 'Ghost Slimer' }
        
        request opts, (err, reqResp, body) ->
            return if err

            try
                issueInfo = JSON.parse body
                title = if issueInfo.title.length > 100 then issueInfo.title.slice(0, 97) + '...' else issueInfo.title
                response.send "[##{issueNumber}] #{title} (#{issueInfo.html_url})"
            catch e
                console.log "Failed to get issue info:", e.message