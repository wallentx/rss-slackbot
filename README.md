# RSS Slackbot

fetch Feeds, post Slack.com. Designed for run with Docker.

- https://github.com/masuilab/rss-slackbot

[![Build Status](https://travis-ci.org/masuilab/rss-slackbot.svg?branch=master)](https://travis-ci.org/masuilab/rss-slackbot)


## Install Dependencies

    % npm install
    % gem install foreman

## Run

### 1. SlackBot

    % export SLACK_TOKEN=a1b2cdef345
    % DEBUG=rssbot npm start

### 2. Webhook

    % export SLACK_WEB_HOOK_URL=https://xxxx
    % DEBUG=rssbot npm start


## Test

    % npm test
