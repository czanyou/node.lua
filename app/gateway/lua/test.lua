local app   = require('app/init')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')

local json  = require('json')
local wot   = require('wot')


local modbus = require('./modbus')

local gateway = require('./gateway')
local log = require('./log')

local exports = {}



function exports.start()
    print("test start");
    exports.gateway()
    -- exports.modbus()
end




function exports.gateway()
    gateway.app = app

    local options = {}
    options.did = app.get('did')
    print(options.did)
    options.mqtt = app.get('mqtt')
    print(options.mqtt)
    options.secret = app.get('secret')
    print(options.secret)
    app.gateway = gateway.createThing(options)

    log.init(app.gateway)
end




exports.start()