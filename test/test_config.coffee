assert = require "assert"
path   = require "path"

describe "config.json", ->

  config =
    try
      require path.resolve 'config.json'
    catch err
      err

  it 'should be valid json', ->

    assert.ok !(config instanceof Error)

  it 'should have property "interval"', ->

    assert.equal typeof config['interval'], 'number'

  it 'should have property "slack"', ->

    assert.equal typeof config['slack'], 'object'

  it 'should have channels', ->

    assert.ok config['channels'] instanceof Array

  it 'should have channels.name', ->

    assert.ok config['channels'][0]['name'] != null

  it 'should have channels.feeds', ->

    assert.ok config['channels'][0]['feeds'] instanceof Array
