import QtQuick 2.12
import QtQuick.Controls 2.12

Item {
    id: root
    property alias labels: chartDataModel.labels
    property alias datasets: chartDataModel.datasets
    property alias colors: chartDataModel.colors
    property double minValue: chartDataModel.minValue
    property double maxValue: chartDataModel.maxValue
    property bool autoscale: chartDataModel.autoscale

    // data model proxy to ChartData context property
    QtObject {
        id: chartDataModel
        property var labels: ChartData.labels
        property var datasets: ChartData.datasets
        property var colors: ChartData.colors
        property double minValue: ChartData.minValue
        property double maxValue: ChartData.maxValue
        property bool autoscale: ChartData.autoscale
    }

    width: 800
    height: 700

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Row {
            id: contentRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: 20

            Canvas {
                id: radarCanvas
                width: Math.min(parent.width * 0.85, 640)
                height: width
                anchors.verticalCenter: parent.verticalCenter

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0,0,width,height);

                    var cx = width/2;
                    var cy = height/2;
                    var radius = Math.min(width, height)/2 * 0.75;
                    var labels = chartDataModel.labels;
                    var datasets = chartDataModel.datasets;
                    var colors = chartDataModel.colors || [];

                    if (!labels || labels.length === 0) {
                        // nothing to draw
                        return;
                    }

                    // Determine min/max scaling
                    var minV = chartDataModel.minValue;
                    var maxV = chartDataModel.maxValue;
                    var useAutoscale = chartDataModel.autoscale;

                    if (useAutoscale) {
                        var foundMin = Number.POSITIVE_INFINITY;
                        var foundMax = Number.NEGATIVE_INFINITY;
                        for (var di=0; di<datasets.length; ++di) {
                            var d = datasets[di];
                            var vals = d["data"];
                            for (var vi=0; vi<vals.length; ++vi) {
                                var x = Number(vals[vi]);
                                if (!isNaN(x)) {
                                    if (x < foundMin) foundMin = x;
                                    if (x > foundMax) foundMax = x;
                                }
                            }
                        }
                        if (foundMin !== Number.POSITIVE_INFINITY) {
                            var pad = (foundMax - foundMin) * 0.05;
                            if (isNaN(pad) || pad === 0) pad = Math.abs(foundMax) * 0.05 + 1.0;
                            minV = foundMin - pad;
                            maxV = foundMax + pad;
                        } else {
                            minV = 0; maxV = 100;
                        }
                    }

                    if (maxV <= minV) {
                        maxV = minV + 1.0;
                    }

                    var axes = labels.length;
                    // Draw grid rings
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = "rgba(200,200,200,0.6)";
                    ctx.fillStyle = "transparent";

                    var ringCount = 4;
                    for (var r=1; r<=ringCount; ++r) {
                        var rr = radius * (r / ringCount);
                        ctx.beginPath();
                        for (var a=0; a<axes; ++a) {
                            var ang = (Math.PI * 2) * (a / axes) - Math.PI/2;
                            var x = cx + Math.cos(ang) * rr;
                            var y = cy + Math.sin(ang) * rr;
                            if (a===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
                        }
                        ctx.closePath();
                        ctx.stroke();
                    }

                    // Draw axis lines and labels
                    ctx.font = Math.floor(width*0.03) + "px sans-serif";
                    ctx.fillStyle = "#333";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";

                    for (var a=0; a<axes; ++a) {
                        var ang = (Math.PI * 2) * (a / axes) - Math.PI/2;
                        var x = cx + Math.cos(ang) * radius;
                        var y = cy + Math.sin(ang) * radius;
                        // axis line
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(x, y);
                        ctx.stroke();

                        // label at slightly beyond radius
                        var lx = cx + Math.cos(ang) * (radius + 28);
                        var ly = cy + Math.sin(ang) * (radius + 28);
                        ctx.fillStyle = "#333";
                        ctx.fillText(labels[a], lx, ly);
                    }

                    // For each dataset, draw polygon
                    for (var di=0; di<datasets.length; ++di) {
                        var d = datasets[di];
                        var vals = d["data"] ? d["data"] : [];
                        var color = colors[di] !== undefined ? colors[di] : ("hsl(" + ((di*80)%360) + ", 60%, 40%)");
                        var fillColor = color;
                        // Draw area
                        ctx.beginPath();
                        for (var i=0;i<axes;++i) {
                            var v = (i < vals.length) ? Number(vals[i]) : 0;
                            if (isNaN(v)) v = 0;
                            var frac = 0.0;
                            if (maxV > minV) frac = (v - minV) / (maxV - minV);
                            if (frac < 0) frac = 0;
                            if (frac > 1) frac = 1;
                            var rr = frac * radius;
                            var ang = (Math.PI * 2) * (i / axes) - Math.PI/2;
                            var x = cx + Math.cos(ang) * rr;
                            var y = cy + Math.sin(ang) * rr;
                            if (i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
                        }
                        ctx.closePath();
                        ctx.fillStyle = fillColorConvert(fillColor, 0.25);
                        ctx.strokeStyle = fillColorConvert(fillColor, 1.0);
                        ctx.lineWidth = 2;
                        ctx.fill();
                        ctx.stroke();

                        // draw points
                        for (var i=0;i<axes;++i) {
                            var v = (i < vals.length) ? Number(vals[i]) : 0;
                            if (isNaN(v)) v = 0;
                            var frac = (maxV > minV) ? (v - minV) / (maxV - minV) : 0;
                            frac = Math.max(0, Math.min(1, frac));
                            var rr = frac * radius;
                            var ang = (Math.PI * 2) * (i / axes) - Math.PI/2;
                            var x = cx + Math.cos(ang) * rr;
                            var y = cy + Math.sin(ang) * rr;
                            ctx.beginPath();
                            ctx.arc(x, y, 4, 0, Math.PI*2);
                            ctx.fillStyle = fillColorConvert(fillColor, 1.0);
                            ctx.fill();
                            ctx.strokeStyle = "#fff";
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }
                    }
                }

                // helper to convert color string to rgba with alpha (simple handling)
                function fillColorConvert(col, alpha) {
                    if (typeof col === "string") {
                        if (col[0] === "#") {
                            var r = parseInt(col.substr(1,2),16);
                            var g = parseInt(col.substr(3,2),16);
                            var b = parseInt(col.substr(5,2),16);
                            return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
                        }
                        if (col.indexOf("rgba") !== -1) {
                            return col;
                        }
                    }
                    return "rgba(100,150,200," + alpha + ")";
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: ChartData
                    onLabelsChanged: radarCanvas.requestPaint()
                    onDatasetsChanged: radarCanvas.requestPaint()
                    onMinMaxChanged: radarCanvas.requestPaint()
                    onColorsChanged: radarCanvas.requestPaint()
                    onAutoscaleChanged: radarCanvas.requestPaint()
                }
            }

            // Legend on the right
            Column {
                width: 180
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: ChartData.datasets.length
                    delegate: Row {
                        spacing: 8
                        Rectangle {
                            width: 28; height: 14
                            color: (ChartData.colors && ChartData.colors[index]) ? ChartData.colors[index] : "lightgray"
                            border.width: 1
                            radius: 2
                        }
                        Text {
                            text: ChartData.datasets[index] ? ChartData.datasets[index]["label"] : ("Series " + (index+1))
                            font.pixelSize: 14
                            color: "#333"
                        }
                    }
                }
            }
        }
    }
}
