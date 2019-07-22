local app   = require('app/init')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')

local httpd  = require('wot/bindings/http')
local ssdpServer = require('ssdp/server')

local gateway = require('./gateway')
local log = require('./log')

local exports = {}

function exports.config()
    console.log('gateway', app.get('gateway'))
end

function exports.ssdp()
    local version = process.version
    local did = app.get('did');
    local model = 'DT02/' .. version
	local ssdpSig = "Node.lua/" .. version .. ", UPnP/1.0, ssdp/" .. ssdpServer.version
    local options = { 
        udn = 'uuid:' .. did, 
        ssdpSig = ssdpSig, 
        deviceModel = model 
    }

    exports.ssdpServer = ssdpServer(options)
end

function exports.gateway()
    gateway.app = app
    
    -- options
    -- - did
    -- - mqtt
    -- - secret
    local options = {}
    options.did = app.get('did')
    options.mqtt = app.get('mqtt')
    options.secret = app.get('secret')
    app.gateway = gateway.createThing(options)

    log.init(app.gateway)
end

function exports.start()
    exports.ssdp()
    exports.gateway()
end

app(exports)
