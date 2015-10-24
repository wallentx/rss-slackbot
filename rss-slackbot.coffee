path = require 'path'
request = require 'request'
FeedParser = require 'feedparser'
async = require 'async'
debug = require('debug')('rssslack')
Slackbot = require 'slackbot'
Slack = require 'node-slack'
Url = require 'url'

Interval = 600

## Envs
RSS_CONFIG_URL = process.env.RSS_CONFIG_URL
SLACK_TOKEN = process.env.SLACK_TOKEN
SLACK_WEB_HOOK_URL = process.env.SLACK_WEB_HOOK_URL
should_send_sample_once = process.env.SHOULD_SEND_SAMPLE_ONCE?  # for DEBUG


## Fetcher

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
            cache_id = "#{entry.url}:#{entry.title}"
            return if cache[cache_id]?
            cache[cache_id] = entry.date
            if !opts.silent or should_send_sample_once
              console.log "#{JSON.stringify entry}"
              should_send_sample_once = false
              callback channel,entry
        setTimeout ->
          next()
        , 1000


## Config

fetch_config = (callback) ->
  if RSS_CONFIG_URL?
    request.get RSS_CONFIG_URL, (error, response, body) ->
      if error or response.statusCode != 200
        callback error, null
      else
        callback null, (JSON.parse body)
  else
    callback null, (require path.resolve 'config.json')

## Notification

create_notify = (config) ->
  if SLACK_TOKEN?
    slack_bot = new Slackbot config.slack.team, process.env.SLACK_TOKEN
  if SLACK_WEB_HOOK_URL?
    slack_hook = new Slack SLACK_WEB_HOOK_URL
  return (channel, entry, callback) ->
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


## Run

run_with_config = (config, opts) ->
  console.log config
  notify = create_notify config
  onNewEntry = (channel, entry) ->
    debug "new entry - #{JSON.stringify entry}"
    notify channel, entry, (err, res) ->
      if err
        debug "notify error : #{err}"
        return
      debug res.body
  for channel in config.channels
    debug "for channel: #{channel.name}"
    console.log "for channel: #{channel.name}"
    fetch_feeds_and_send_to(channel.name, channel.feeds, opts, onNewEntry)


run = (opts = {}) ->
  fetch_config (err, config) ->
    if err
      console.error "error: '#{RSS_CONFIG_URL}' #{error || body}"
      return
    run_with_config config, opts



## Main
unless SLACK_TOKEN? or SLACK_WEB_HOOK_URL?
  console.error "set ENV variable  e.g. SLACK_TOKEN=a1b2cdef3456 or SLACK_WEB_HOOK_URL=http://..."
  process.exit 1

setInterval ->
  run
, 1000 * Interval
run {silent: true}  # 最初の1回は通知しない
