
function get_chart(chart, options) {
    
    chart   = chart   || {}
    options = options || {}

    var left    = options.left   || 0
    var top     = options.top    || 0
    var width   = options.width  || 600
    var height  = options.height || 200

    var series  = chart.series   || {}
    var line1   = series[0]      || {}
    var list    = line1.data     || {}
    var labels  = chart.labels   || {}

    // 

    var minValue = Number.MAX_VALUE
    var maxValue = Number.MIN_VALUE

    for (index = 1; index <= series.length; index++) {
        var line = series[index - 1]
        var data = line.data || {}
        var count = data.length

        for (i = 1; i <= count; i++) {
            var value = data[i - 1]
            if (! value) {
                continue

			} else if (value == -1) {
                continue
            }

            if (value < minValue) {
                minValue = value
			}

            if (value > maxValue) {
                maxValue = value
			}
		}
	}

    if (minValue == Number.MAX_VALUE) {
        minValue = -1
    }

    if (maxValue == Number.MIN_VALUE) {
        maxValue = 1
    }

    var count = labels.length || list.length

    // yAxis
    var sb = ""
    sb += '<g>'

/*
    sb += '<rect x="'
    sb += left + 0.5
    sb += '" y="'
    sb += top + 0.5
    sb += '"  width="'
    sb += width
    sb += '" height="'
    sb += height
    sb += '" class="rect"/>'*/

    var padding = 16
    left    += padding
    top     += padding
    width   -= padding * 2
    height  -= padding * 2 + 24
    var offsetX = left
    var offsetY = top

    var lineY   = 4
    var maxY    = maxValue - maxValue % 5 + 5
    var minY    = minValue - minValue % 5

    var stepY   = (maxY - minY) / lineY  
    var spanX   = width / count  // px
    var spanY   = height / lineY  // px
    var scale   = (spanY * lineY) / (maxY - minY)

    var floor = Math.floor

    for (i = 1; i <= lineY + 1; i++) {
        var x1 = offsetX
        var x2 = x1 + width
        var y  = floor(offsetY + (i - 1) * spanY) + 0.5 // 0.5 让线条更清晰

        // y-axis line
        sb += '<line x1="'
        sb += x1 + 24
        sb += '" y1="'
        sb += y
        sb += '" x2="'
        sb += x2
        sb += '" y2="'
        sb += y
        sb += '" class="'

        if (i > lineY) {
            sb += 'line0'; 

        } else {
            sb += 'line1'; 
        }

        sb += '"/>'

        // y-axis label
        var value = floor(maxY - (i - 1) * stepY + 0.5)
        if (count >= 1) {
            sb += '<text id="text" x="'
            sb += x1
            sb += '" y="'
            sb += (y + 3)
            sb += '" class="text0" text-anchor="start">'
            sb += value
            sb += '</text>'
	    }
	}

    sb += '</g>'

    if (count <= 1) {
        return sb
	}

    // xAxis
    var x1 = offsetX
    var y1 = offsetY
    var y2 = offsetY + spanY * lineY + 2
    //sb += '<line x1="' + x1 + '" y1="' + y1)
    //sb += ''" x2="' + x1 + '" y2="' + y2 + '" class="line0"/>')

    // categories labels
    var labels = chart.labels || {}
    var labelCount = Math.floor(width / 60)
    var skip = 1
    while (true) {
        if (count / skip <= labelCount) {
            break
        }
        skip = skip + 1
    }
    var mode = count % skip

    //console.log('skip', skip, labelCount)

    sb += '<g class="categories">'
    for (i = 1; i <= labels.length; i++) {
        var x = floor(offsetX + (i - 0.5) * spanX)
        var y = floor(offsetY + lineY * spanY)

        if ((i % skip) == mode || (skip == 1)) {
            sb += '<text id="text" class="text0" text-anchor="middle" x="'
            sb += (x - 3)
            sb += '" y="'
            sb += (y + 20)
            sb += '">'
            sb += labels[i - 1]
            sb += '</text>'
		}
    }
    sb += '</g>'


    // series line
    for (index = 1;	index <= series.length; index++) {
        var line = series[index - 1]
        var name = line.name
        var data = line.data || {}
        var count = data.length

        sb += '<g>'

        // polyline1
        var sep = 'M'
        sb += '<path class="polyline'
        sb += index
        sb += '" d="'
        for (i = 1; i <= count; i++) {
            var value = data[i - 1];
            if (!value || value == -1) {
                continue
            }

            value -= minY
            var x = floor(offsetX + (i - 0.5) * spanX + 0.5)
            var y = floor(offsetY + lineY * spanY - value * scale + 0.5)

            sb += sep          
            sb += x
            sb += " "
            sb += y
            sb += ' '
            sep = 'L'
        }
        sb += '"/>'

        // point
        //**
        for (i = 1; i <= count; i++) {
            var value = data[i - 1];
            if (!value || value == -1) {
                continue
            }
            
            value -= minY
            var x = floor(offsetX + (i - 0.5) * spanX - 2 + 0.5)
            var y = floor(offsetY + lineY * spanY - value * scale - 2 + 0.5)
            sb += '<rect alt="test" x="'
            sb += x
            sb += '" y="'
            sb += y
            sb += '"  width="5" height="5" class="point'
            sb += index
            sb += '"/>'
        }
        //*/

        sb += '</g>'
    }

    return sb
}

function get_chart_html(chart, viewWidth, viewHeight) {
    var html = ""
    html += '<svg width="100%" height="100%" version="1.1"'
    html += ' xmlns="http://www.w3.org/2000/svg">'
    html += get_chart(chart || {}, { width: viewWidth, height: viewHeight })
    html += "</svg>"
    return html
}
