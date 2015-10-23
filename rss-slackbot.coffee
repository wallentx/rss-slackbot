path = require 'path'
request = require 'request'
FeedParser = require 'feedparser'
async = require 'async'
debug = require('debug')('rssslack')
Slackbot = require 'slackbot'
Slack = require 'node-slack'
Url = require 'url'

SLACK_TOKEN = process.env.SLACK_TOKEN
SLACK_WEB_HOOK_URL = process.env.SLACK_WEB_HOOK_URL

# for DEBUG
should_send_sample_once = process.env.SHOULD_SEND_SAMPLE_ONCE?


unless SLACK_TOKEN? or SLACK_WEB_HOOK_URL?
  console.error "set ENV variable  e.g. SLACK_TOKEN=a1b2cdef3456 or SLACK_WEB_HOOK_URL=http://..."
  process.exit 1

console.log config = require path.resolve 'config.json'

if SLACK_TOKEN?
  slack_bot = new Slackbot config.slack.team, process.env.SLACK_TOKEN
if SLACK_WEB_HOOK_URL?
  slack_hook = new Slack SLACK_WEB_HOOK_URL

notify = (channel, entry, callback) ->
  msg = ""
  msg += "#{entry.title}\n"
  msg += "##{entry.comment}\n"  if entry.comment?
  msg += "#{entry.url}"
  if slack_bot
    slack_bot.send channel, "#{config.slack.header} #{msg}", callback
  else
    slack_hook.send {
      channel: channel,
      username: "#{config.slack.header}#{entry.feed_title}",
      text: msg,
      icon_url: 'https://slack.global.ssl.fastly.net/66f9/img/services/rss_64.png',
      unfurl_links: true},
      callback

cache = {}

fetch = (feed_url, callback = ->) ->
  try
    feed = request(feed_url).pipe(new FeedParser)
  catch err
    callback err
    return
  entries = []
  feed.on 'error', (err) ->
    callback err
  feed.on 'data', (chunk) ->
    entry = {url: chunk.link, title: chunk.title, date: chunk.date, feed_title: this.meta.title}
    entry['comment'] = chunk["rdf:description"]?["#"]  if Url.parse(feed_url).hostname == 'b.hatena.ne.jp'
    entries.push entry
  feed.on 'end', ->
    callback null, entries


fetch_feeds_and_send_to = (channel, feeds, opts = {}, callback) ->
    async.eachSeries feeds, (url, next) ->
      fetch url, (err, entries) ->
        debug "channel: #{channel}, url: #{url}"
        if err
          debug JSON.stringify err
          next()
          return
        for entry in entries
          do (entry) ->
            debug "fetch [#{channel}]- #{JSON.stringify entry}"
            cache_id = entry.url + entry.date
            return if cache[cache_id]?
            cache[cache_id] = entry.title
            if !opts.silent or should_send_sample_once
              console.log "#{JSON.stringify entry}"
              should_send_sample_once = false
              callback channel,entry
        setTimeout ->
          next()
        , 1000


run = (opts = {}, callback) ->
  for channel in config.channels
    debug "for channel: #{channel.name}"
    fetch_feeds_and_send_to(channel.name, channel.feeds, opts, callback)


onNewEntry = (channel, entry) ->
  debug "new entry - #{JSON.stringify entry}"
  notify channel, entry, (err, res) ->
    if err
      debug "notify error : #{err}"
      return
    debug res.body

## Run
setInterval ->
  run null, onNewEntry
, 1000 * config.interval

run {silent: true}, onNewEntry  # 最初の1回は通知しない
