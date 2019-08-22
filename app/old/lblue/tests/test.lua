local utils = require('util')
local printr  = utils.printr
local x = {
	{
		mac='123',
		data={
			{
				id='123'
			},
			{
				id='123'
			}
		}
	},{
		mac='456',
		data=
		{
			id='456'
		}
	},{
		mac='789',
		data=
		{
			id='789'
		}
	}
}
local IBeaconsList = {}
local StackHead = 5
local ibeacon1  = {
	mac='123',
	UUID='123',
	major='123',
	minor='123',
	rssi='123',
	txpower={'123'}
}
local ibeacon11  = {
	mac='123',
	UUID='123',
	major='123',
	minor='123',
	rssi='123',
	txpower={'1231'}
}
local ibeacon12  = {
	mac='123',
	UUID='123',
	major='123',
	minor='123',
	rssi='123',
	txpower={'1232'}
}
local ibeacon13  = {
	mac='123',
	UUID='123',
	major='123',
	minor='123',
	rssi='123',
	txpower={'1233'}
}
local ibeacon14  = {
	mac='123',
	UUID='123',
	major='123',
	minor='123',
	rssi='123',
	txpower={'1234'}
}
local ibeacon15  = {
	mac='123',
	UUID='123',
	major='123',
	minor='123',
	rssi='123',
	txpower={'1235'}
}

local ibeacon2  = {
	mac='456',
	UUID='456',
	major='456',
	minor='456',
	rssi='456',
	txpower={'456'}
}
local ibeacon21  = {
	mac='456',
	UUID='456',
	major='456',
	minor='456',
	rssi='456',
	txpower={'123'}
}
local ibeacon22  = {
	mac='456',
	UUID='456',
	major='456',
	minor='456',
	rssi='456',
	txpower={'456'}
}
local ibeacon23  = {
	mac='456',
	UUID='456',
	major='456',
	minor='456',
	rssi='456',
	txpower={'678'}
}
local ibeacon24  = {
	mac='456',
	UUID='456',
	major='456',
	minor='456',
	rssi='456',
	txpower={'789'}
}
local ibeacon25  = {
	mac='456',
	UUID='456',
	major='456',
	minor='456',
	rssi='456',
	txpower={'432'}
}


local function putIBeaconAdvance(ibeacon)
    -- body
    local flag = false
    if(#IBeaconsList ~= 0)then
        for i= 1, #IBeaconsList do
            if(IBeaconsList[i].UUID == ibeacon.UUID)then
            	local index = IBeaconsList[i].number%StackHead + 1
            	IBeaconsList[i].number = IBeaconsList[i].number + 1
            	printr('index  : ' .. index .. ' txpower : ' .. ibeacon.txpower[1])
            	IBeaconsList[i].txpower[index] = ibeacon.txpower[1]
                flag = true
                break
            end
        end
    end
    if(flag == false)then
    	ibeacon.number = 1
        IBeaconsList[#IBeaconsList+1] = ibeacon
    end
end

putIBeaconAdvance(ibeacon1)
putIBeaconAdvance(ibeacon11)
putIBeaconAdvance(ibeacon12)
putIBeaconAdvance(ibeacon13)
putIBeaconAdvance(ibeacon14)
putIBeaconAdvance(ibeacon15)
printr('putIBeaconAdvance : ' .. ibeacon1.txpower[1])
putIBeaconAdvance(ibeacon1)
-- printr('ibeacon : ' .. ibeacon1.txpower[1])


putIBeaconAdvance(ibeacon2)
putIBeaconAdvance(ibeacon21)
putIBeaconAdvance(ibeacon22)
putIBeaconAdvance(ibeacon23)
putIBeaconAdvance(ibeacon24)
putIBeaconAdvance(ibeacon25)

-- ibeacon1.txpower[1] = '124'
-- putIBeaconAdvance(ibeacon1)
-- ibeacon1.txpower[1] = '125'
-- putIBeaconAdvance(ibeacon1)

-- putIBeaconAdvance(ibeacon2)
-- ibeacon2.txpower[1] = '124'
-- putIBeaconAdvance(ibeacon2)
-- ibeacon2.txpower[1] = '125'
-- putIBeaconAdvance(ibeacon2)
printr(IBeaconsList)

-- local x = 6
-- printr(3%StackHead)
-- printr(x[1].data)