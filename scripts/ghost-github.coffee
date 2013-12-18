# Description:
#   Github Webhook Responding for TryGhost
#
# Dependencies:
#   git-at-me (npm install git-at-me --save)
#
# Commands:
#   None

github = require('git-at-me')

devRoom = '#ghost'

module.exports = (robot) ->

    return unless robot.router

    githubEvents = github
        # TESTING: Must be generated with github.wizard()
        #token: require('../github-token')
        # Repo information for creating a webhook; not needed for Ghost since it will be created by Hannah
        #user: 'jgable'
        #repo: 'Slimer'
        #events: ['push', 'pull_request', 'issues', 'issue_comment']
        # TESTING: Using ngrok to generate this while testing
        url: "http://#{process.env.HUBOT_HOSTNAME}/github/events"
        skipHook: true
        server: robot.router

    githubEvents.on 'push', (pushData) ->
        author = pushData.pusher.name
        commits = pushData.commits.length
        branch = pushData.ref.replace('refs/heads/', '')
        repo = "#{pushData.repository.owner.name}/#{pushData.repository.name}"
        compareUrl = pushData.compare

        # Only output commits to master
        return unless branch == 'master'

        # Format: <Slimer> ErisDS pushed 2 commits to master on TryGhost/Ghost - https://github.com/jgable/git-at-me/compare/b29e18b9b2db...3722cee576e1
        robot.messageRoom devRoom, "#{author} pushed #{commits} commits to #{branch} on #{repo} - #{compareUrl}"

    
    githubEvents.on 'pull_request', (prData) ->
        { action, number, pull_request, sender, repository } = prData
        { html_url, title, user } = pull_request

        action = "merged" if pull_request.merged

        action = "updated" if action == "synchronize"

        # Format: <Slimer> ErisDS merged PR #102 on TryGhost/Ghost - Fix bug on image uploader, fixes #92 - by JohnONolan - http://github.com/TryGhost/Ghost/Pulls/102
        msg = "#{sender.login} #{action} PR ##{number} on #{repository.full_name} - #{title} - #{html_url}"

        robot.messageRoom devRoom, msg


    githubEvents.on 'issues', (issueData) ->
        { action, issue, repository, sender } = issueData

        # Format: <Slimer> gotdibbs created issue #1035 on TryGhost/Ghost - File uploads CSRF protection
        msg = "#{sender.login} #{action} Issue ##{issue.number} on #{repository.full_name} - #{issue.title} - #{issue.html_url}"

        robot.messageRoom devRoom, msg

    githubEvents.on 'issue_comment', (commentData) ->
        # Not reporting on comments right now
        return

        { action, issue, comment, repository, sender } = commentData

        return unless action == 'created'

        # Format: <Slimer> jgable commented on issue #3 on TryGhost/Ghost - File uploads CSRF protection
        msg = "#{sender.login} commented on Issue ##{issue.number} on #{repository.full_name} - #{issue.title} - #{comment.html_url}"

        robot.messageRoom devRoom, msg

    
    githubEvents.on 'error', (err) ->
        console.log "Error in githubEvents: #{err.message}"
