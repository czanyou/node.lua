local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local express = require('express')
local ssdpServer = require('ssdp/server')

local gateway = require('./gateway')
local log = require('./log')

local exports = {}

function exports.config()
    console.log('gateway', app.get('gateway'))
end

function exports.ssdp()
    local version = process.version
    local did = app.get('did') or gateway.getMacAddress();
    local model = 'DT02/' .. version
    local ssdpSig = "lnode/" .. version .. ", ssdp/" .. ssdpServer.version
    
    local options = {
        udn = 'uuid:' .. did, 
        ssdpSig = ssdpSig, 
        deviceModel = model 
    }
    -- console.log(options, did)
    local server, error = ssdpServer(options)
    if (error) then
        print('Start sddp error:', error)
        return
    end

    exports.ssdpServer = server
end

function exports.gateway()
    -- options
    -- - did
    -- - mqtt
    -- - secret
    local options = {}
    options.did = app.get('did')
    options.mqtt = app.get('mqtt')
    options.secret = app.get('secret')

    local gateway, error = gateway.createThing(options)
    if (error) then
        print('Create thing error:', error)
        return
    end

    app.gateway = gateway
    log.init(app.gateway)
end

function exports.start()
    exports.ssdp()
    exports.gateway()
end

app(exports)
