local wot = require('wot')
local fs = require('fs')
local exec = require('child_process').exec

-- Gateway Model

List = {}

function List.new ()
    return { first = 0, last = -1 }
end

function List.pushLeft (list, value)
    local first = list.first - 1
    list.first = first
    list[first] = value
end

function List.pushRight (list, value)
    local last = list.last + 1
    list.last = last
    list[last] = value
end

function List.isEmpty(list)
    if list.first > list.last then 
        return true
    end

    return false
end

function List.popLeft (list)
    local first = list.first

    if first > list.last then 
        return nil
    end

    local value = list[first]

    list[first] = nil    -- to allow garbage collection
    list.first = first + 1
    return value
end


function List.popRight (list)
    local last = list.last
    if list.first > last then 
        return nil 
    end

    local value = list[last]
    list[last] = nil     -- to allow garbage collection
    list.last = last - 1
    return value
end

-- ----------------------------------------------------------------------------
-- Gateway Model

local model = {
    id = 'svn:wot:com:bn:gateway',
    name = "gateway",
    description = 'Gateway for Web of Thing',
    support = 'tour.beaconice.cn'
}

local gateway = wot.produce(model)

gateway.tasks = List.new()
gateway.display = {}
gateway.devices = {}

-- ----------------------------------------------------------------------------
-- Properties

local statusPropery = {
    type = "object",
    label = "Status",
    description = "System status",
    writable = false,
    observale = false,
    mandatory = { "version" },
    properties = {
        version = {
            type = "string"
        },
        name = {
            type = "string"
        },
        code = {
            type = "integer",
            minimum = 0,
            maximum = 100
        }
    }
}

local statusProperyHandler = function(name) 
    console.log(name)

    return {
        version = "1.0.0",
        name = "gateway",
        busy = gateway.isbusy,
        devices = gateway.devices,
        code = 100
    }
end

local displayPropery = {
    type = "object",
    label = "Status",
    description = "System status",
    writable = false,
    observale = false,
    mandatory = { "version" },
    properties = {
        version = {
            type = "string"
        },
        name = {
            type = "string"
        },
        code = {
            type = "integer",
            minimum = 0,
            maximum = 100
        }
    }
}

local displayProperyHandler = function(name) 
    console.log(name)

    return {
        version = "1.0.0",
        name = "gateway",
        busy = gateway.isbusy,
        devices = gateway.devices,
        code = 100
    }
end

gateway:addProperty("status", statusPropery);
gateway:setPropertyReadHandler("status", statusProperyHandler)

gateway:addProperty("display", displayPropery);
gateway:setPropertyReadHandler("display", displayProperyHandler)

-- ----------------------------------------------------------------------------
-- Actions

local displayAction = {
    label = "Display",
    description = "Display action",
    input = {
        type = "object",
        properties = {
            did = {
                type = "string"
            },
            data = {
                type = "string"
            },
            width = {
                type = "integer"
            },
            height = {
                type = "integer"
            },
            colors = {
                type = "integer"
            }
        }
    },
    output = {
        type = "integer"
    }
}

local onLabelDisplay = function(device, params)
    console.log("display", device);

    local data = params.data or '';
    local name = params.name;

    if (not device.desired) then
        device.desired = {}
    end

    local display = {}
    display.did = params.did
    display.name = params.name
    display.width = params.width
    display.height = params.height
    display.colors = params.colors

    if (display.name and params.data) then
        -- check file data & name
        local filename = "/usr/local/display/"
        if (not fs.existsSync(filename)) then
            fs.mkdirSync(filename);
        end

        filename = filename .. params.name
        local oldData = fs.readFileSync(filename);
        if (oldData ~= params.data) then
            fs.writeFileSync(filename, params.data);
        end
    end

    device.desired.display = display;

    return { code = 0 }
end

local displayActionHandler = function(params)
    -- console.log('@display', params)

    if (not params) or (not params.did) then
        return
    end

    local mac = params.did;
    if (not mac) then
        return { code = -1 }
    end

    local device = gateway.devices[mac]
    if (not device) then
        device = { did = mac }
        gateway.devices[mac] = device;
    end

    return onLabelDisplay(device, params)
end

gateway:addAction("display", displayAction, displayActionHandler)

-- ----------------------------------------------------------------------------
-- Events

local statusEvent = {
    label = "StatusChange",
    description = "Status change",
    type = "string"
}

gateway:addEvent("status", statusEvent)

-- ----------------------------------------------------------------------------

function onLabelDisplayTask(params)
    local mac = params.did or '';
    local name = params.name or '';
    local filename = "/usr/local/display/"
    if (name) then
        filename = filename .. name
    else
        filename = filename .. mac
    end

    local cmdline = ('pc-ble-driver-test display ' .. mac .. ' ' .. filename .. '.bin');
    console.log(cmdline)

    gateway.isbusy = true;
    exec(cmdline, {}, function(err, stdout, stderr) 
        gateway.isbusy = false;

        if (err) then
            console.log('err', err)
            params.tryTimes = (params.tryTimes or 0) + 1;
            return
        end

        print('stdout', stdout, stderr)
        params.tryTimes = 0;

        onLabelDisplayReport(mac, params)
    end);
end

function onLabelDisplayReport(did, params)
    local devices = gateway.devices or {}
    local device = devices[did]
    if (not device) then
        return
    end

    if (not device.reported) then
        device.reported = {}
    end

    device.reported.display = params
end

local onExecuteDisplay = function(display)
    console.log('execute display:', display)
    gatewayTaskHandler({ params = display })
end

local isDesiredChanged = function(device, name)
    if (not device) then
        return false
    end

    local desired = device.desired or {}
    local reported = device.reported or {}
    local desiredValue = desired[name]
    local reportedValue = reported[name]
    if (not desiredValue) then
        return false
    end

    if desiredValue.tryTimes and (desiredValue.tryTimes > 10) then
        return false
    end

    if (not reportedValue) then
        return true

    elseif (reportedValue.name ~= desiredValue.name) then
        return true
    end

    return false
end

local onGatewayTask = function(task)
    local device = gateway.devices[task.did]
    if (isDesiredChanged(device, 'display')) then
        local params = device.desired.display
        onLabelDisplayTask(params)
    end
end

gateway.checkList = {}

local onCheckDisplayChanges = function() 
    local devices = gateway.devices or {}
    local tasks = gateway.tasks
    for mac, device in pairs(devices) do
        if (isDesiredChanged(device, 'display')) then
            local task = { name = "display", did = mac }
            List.pushRight(tasks, task)
        end
    end
end

setInterval(1000, function()
    -- console.log('task');
    if (gateway.isbusy) then
        -- console.log('busy')
        return;
    end

    -- check update
    local tasks = gateway.tasks
    if (List.isEmpty(tasks)) then
        onCheckDisplayChanges()
    end

    -- task
    local task = List.popLeft(tasks)
    if (task) then
        -- console.log('task', task);
        onGatewayTask(task)
    end
end)

return gateway
