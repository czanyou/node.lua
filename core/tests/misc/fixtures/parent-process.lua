
setInterval(100, function()
    print('test')
end)

process.stdin:on('data', function(data)
    print('stdin', data)
    process:exit(110)
end)
