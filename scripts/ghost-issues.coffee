# Description:
#   Github utility commands for issues
#
# Commands:
#   [User/][Repo]#1234 - Reply with link to issue
#
# Notes:
#   User and Repo are optional.
#
#   Multiple issue numbers per line are supported.
#
#   Slimer will attempt to resolve repositories by prepending "Ghost-" to repositories
#   that are not found on the first attempt.
#
#   Slimer will attempt to resolve repositories by removing "Ghost-" from repositories
#   that are not found on the first attempt.
#
# Examples:
#   #99 =>  TryGhost/Ghost#99
#
#   Casper#99 => TryGhost/Casper#99
#
#   Ghost-Casper#99 => TryGhost/Casper#99
#
#   UI#99 => TryGhost/Ghost-UI#99
#
#   visionmedia/express#10 => visionmedia/express#10

request = require 'request'

urls = 
    repo: (user, repo) -> "https://api.github.com/repos/#{user}/#{repo}"
    issue: (user, repo, number) -> @repo(user, repo) + "/issues/#{number}"

headers = { 'User-Agent': 'Ghost Slimer' }

module.exports = (robot) ->
    robot.hear /[a-zA-Z0-9-]*\/*[a-zA-Z0-9-]*#[0-9]+/g, (response) ->
        issues = []
        response.match.forEach (match) ->
            [location, issueNumber] = match.split("#")

            location = location.split("/")

            if location.length == 2
                [user, repo] = location
            else if location.length == 1
                repo = location[0] || "Ghost"
                user = "TryGhost"

            issueUrl = urls.issue user, repo, issueNumber
            searchAttempts = []
            foundIssue = false

            searchAttempts.push { url: issueUrl, headers: headers }

            # if we're on a TryGhost repo, set up a fallback search by either
            # adding or removing "Ghost-" from the repo name
            if repo && user.toLowerCase() == "tryghost"
                if /^ghost-/i.test(repo)
                    issueUrl = urls.issue user, repo.split("-")[1], issueNumber
                    searchAttempts.push { url: issueUrl, headers: headers }
                else
                    issueUrl = urls.issue user, "Ghost-" + repo, issueNumber
                    searchAttempts.push { url: issueUrl, headers: headers }

            options = searchAttempts.pop()
            request options, (err, reqResp, body) ->
                return if err

                try
                    issueInfo = JSON.parse body
                    title = if issueInfo.title.length > 100 then issueInfo.title.slice(0, 97) + '...' else issueInfo.title
                    issues.push "[##{issueNumber}] #{title} (#{issueInfo.html_url})"
                    foundIssue = true
                catch e
                    console.log "Failed to get issue info:", e.message
                    console.log "Request:", options.url, body

                    if searchAttempts.length && !foundIssue
                        options = searchAttempts.pop()
                        request options, (err, reqResp, body) ->
                            return if err

                            try
                                issueInfo = JSON.parse body
                                title = if issueInfo.title.length > 100 then issueInfo.title.slice(0, 97) + '...' else issueInfo.title
                                issues.push "[##{issueNumber}] #{title} (#{issueInfo.html_url})"
                                foundIssue = true
                            catch e
                                console.log "Failed to get issue info:", e.message
                                console.log "Request:", options.url, body
                                issues.push "no info for ##{issueNumber}"

                            if issues.length == response.match.length
                                response.send issues.join ", "
                    else
                        issues.push "no info for ##{issueNumber}"

                    if issues.length == response.match.length
                        response.send issues.join ", "

                if issues.length == response.match.length && foundIssue
                    response.send issues.join ", "
