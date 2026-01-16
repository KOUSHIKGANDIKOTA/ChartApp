import QtQuick 2.12
import QtQuick.Controls 2.12

Item {
    id: root
    width: 800
    height: 700

    // ================= STATE =================
    property int hoverDataset: -1
    property int hoverAxis: -1
    property int selectedDataset: -1
    property point mousePos: Qt.point(0,0)

    // ================= ZOOM & PAN =================
    property real zoomFactor: 1.0
    property real minZoom: 0.4
    property real maxZoom: 10.0

    property real panX: 0
    property real panY: 0

    signal datasetSelected(int index)

    // ================= TOOLTIP =================
    Rectangle {
        id: tooltip
        visible: hoverAxis >= 0 && hoverDataset >= 0
        color: "#000000"
        radius: 4
        opacity: 0.85
        z: 100

        x: mousePos.x + 12
        y: mousePos.y + 12

        Column {
            anchors.margins: 6
            spacing: 2

            Text { color: "black"; font.pixelSize: 12
                text: ChartData.labels[hoverAxis]
            }
            Text { color: "black"; font.pixelSize: 11
                text: "Value: " +
                      ChartData.datasets[hoverDataset]["data"][hoverAxis].toFixed(3)
            }
        }
    }

    // ================= CANVAS =================
    Canvas {
        id: radarCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0,0,width,height)

            var cx = width/2 + panX
            var cy = height/2 + panY

            var baseRadius = Math.min(width,height)*0.38
            var radius = baseRadius * zoomFactor

            var labels = ChartData.labels
            var datasets = ChartData.datasets
            var colors = ChartData.colors

            if (!labels || labels.length === 0)
                return

            var axes = labels.length

            // ---------- GRID ----------
            ctx.strokeStyle = "rgba(200,200,200,0.6)"
            ctx.lineWidth = 1
            for (var r=1;r<=4;r++) {
                ctx.beginPath()
                for (var a=0;a<axes;a++) {
                    var ang = 2*Math.PI*(a/axes) - Math.PI/2
                    var rr = radius*(r/4)
                    var x = cx + Math.cos(ang)*rr
                    var y = cy + Math.sin(ang)*rr
                    if (a===0) ctx.moveTo(x,y)
                    else ctx.lineTo(x,y)
                }
                ctx.closePath()
                ctx.stroke()
            }

            // ---------- AXES ----------
            ctx.font = "12px sans-serif"
            ctx.fillStyle = "#333"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"

            for (var a=0;a<axes;a++) {
                var ang = 2*Math.PI*(a/axes) - Math.PI/2
                ctx.beginPath()
                ctx.moveTo(cx,cy)
                ctx.lineTo(cx + Math.cos(ang)*radius,
                           cy + Math.sin(ang)*radius)
                ctx.stroke()

                ctx.fillText(
                    labels[a],
                    cx + Math.cos(ang)*(radius+26),
                    cy + Math.sin(ang)*(radius+26)
                )
            }

            // ---------- DATASETS ----------
            for (var d=0; d<datasets.length; d++) {
                var vals = datasets[d]["data"]
                var col = colors[d] || "#4C9ED9"
                var isSelected = (d === selectedDataset)

                var fillAlpha = isSelected ? 0.08 : 0.02
                var strokeAlpha = isSelected ? 1.0 : 0.5

                ctx.beginPath()
                for (var i=0;i<axes;i++) {
                    var ang = 2*Math.PI*(i/axes) - Math.PI/2
                    var rr = vals[i]*radius
                    var x = cx + Math.cos(ang)*rr
                    var y = cy + Math.sin(ang)*rr
                    if (i===0) ctx.moveTo(x,y)
                    else ctx.lineTo(x,y)
                }
                ctx.closePath()

                ctx.fillStyle = toRGBA(col, fillAlpha)
                ctx.strokeStyle = toRGBA(col, strokeAlpha)
                ctx.lineWidth = isSelected ? 3 : 1.2
                ctx.fill()
                ctx.stroke()

                // ---------- POINTS ----------
                for (var i=0;i<axes;i++) {
                    var ang = 2*Math.PI*(i/axes) - Math.PI/2
                    var rr = vals[i]*radius
                    var x = cx + Math.cos(ang)*rr
                    var y = cy + Math.sin(ang)*rr

                    ctx.beginPath()
                    ctx.arc(x,y,4,0,Math.PI*2)
                    ctx.fillStyle =
                        (hoverDataset===d && hoverAxis===i) ? "#000" : col
                    ctx.fill()
                }
            }
        }

        // ================= INPUT =================
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            //Mouse-centered zoom
            onWheel: {
                var oldZoom = zoomFactor
                var zoomStep = wheel.angleDelta.y > 0 ? 1.1 : 0.9
                var newZoom = Math.max(minZoom,
                                       Math.min(maxZoom, zoomFactor * zoomStep))

                var ratio = newZoom / oldZoom
                var mx = wheel.x - radarCanvas.width/2 - panX
                var my = wheel.y - radarCanvas.height/2 - panY

                panX -= mx * (ratio - 1)
                panY -= my * (ratio - 1)

                zoomFactor = newZoom
                radarCanvas.requestPaint()
            }

            onPositionChanged: {
                mousePos = Qt.point(mouse.x, mouse.y)
                hoverAxis = -1
                hoverDataset = -1

                var cx = radarCanvas.width/2 + panX
                var cy = radarCanvas.height/2 + panY
                var radius =
                    Math.min(radarCanvas.width,
                             radarCanvas.height)*0.38 * zoomFactor

                for (var d=0; d<ChartData.datasets.length; d++) {
                    var vals = ChartData.datasets[d]["data"]
                    for (var i=0;i<ChartData.labels.length;i++) {
                        var ang = 2*Math.PI*(i/ChartData.labels.length) - Math.PI/2
                        var rr = vals[i]*radius
                        var px = cx + Math.cos(ang)*rr
                        var py = cy + Math.sin(ang)*rr
                        if (Math.hypot(mouse.x-px, mouse.y-py) < 7) {
                            hoverAxis = i
                            hoverDataset = d
                            break
                        }
                    }
                }
                radarCanvas.requestPaint()
            }

            //double-click polygon selection
            onDoubleClicked: {
                if (hoverDataset >= 0) {
                    selectedDataset = hoverDataset
                    root.datasetSelected(selectedDataset)
                } else {
                    selectedDataset = -1
                    root.datasetSelected(-1)
                }
                radarCanvas.requestPaint()
            }
        }
    }

    function toRGBA(hex, a) {
        var r=parseInt(hex.substr(1,2),16)
        var g=parseInt(hex.substr(3,2),16)
        var b=parseInt(hex.substr(5,2),16)
        return "rgba("+r+","+g+","+b+","+a+")"
    }
}
