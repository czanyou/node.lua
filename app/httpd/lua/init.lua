local querystring = require('querystring')

local exports = {}

-- 检查客户端是否已经登录 
function exports.checkLogin(request, response)
	if (request == nil) or (response == nil) then
		return true
	end

	local pathname = request.uri.pathname or ''

	if pathname:endsWith('.html') then
		if (pathname == '/login.html') then
			return false
		end
	else
		if (pathname ~= '/') then
			return false
		end
	end

	local session = request:getSession()
	local userinfo = session and session['userinfo']
	if (userinfo) then
		return false
	end

	response:set('Location', '/login.html')
	response:sendStatus(302)
	return true
end

function exports.isLogin(request)
	if (request == nil) then
		return true
	end

	local session = request:getSession()
	local userinfo = session and session['userinfo']
	if (userinfo) then
		return true
	end

	return false
end


-- call API methods
function exports.call(methods, request, response, flags)
	request.params  = querystring.parse(request.uri.query) or {}
	request.api     = request.params['api']

    local api = request.api
    local method = methods[api]
    if (not method) then
        response:sendStatus(400, "No `api` parameters specified!")
        return
    end

    -- skip noauth API
    local noauth = methods['@noauth']
   	if (noauth) then
   		noauth = noauth[api]
   	end

   	-- check login
    if (not noauth) and (not exports.isLogin(request)) then
        response:json({code = 200, erro = "Unauthorized"})
        return
    end

	request:readBody(function()
		local err

    	local handler = function(message)
        	err = (message or '') .. "\r\n" .. debug.traceback()
    	end

    	local ret = xpcall(method, handler, request, response)
    	if (not ret) then
    		local content = '<pre><code>' .. tostring(err) .. '</code></pre>'
        	response:sendStatus(500, content)
    	end
    end)
end

return exports
