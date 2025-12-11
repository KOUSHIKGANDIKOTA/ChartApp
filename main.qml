import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    width: 900
    height: 600
    title: qsTr("ChartApp - Radar Chart Demo")

    Rectangle {
        anchors.fill: parent
        color: "#ffffff"

        Item {
            id: chartArea
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        console.log("Component.onCompleted — starting debug")

        if (typeof chartBackend === "undefined") {
            console.log("chartBackend is UNDEFINED — ChartData not exposed from C++")
        } else {
            console.log("chartBackend.type:", chartBackend.type)
            console.log("chartBackend.data (length):", chartBackend.data ? chartBackend.data.length : "no data")
            console.log("chartBackend.data:", chartBackend.data)
        }

        var labels = ["Eating","Drinking","Sleeping","Designing","Coding","Partying","Running"];

        var dataset1 = {
            fillColor: "rgba(220,220,220,0.5)",
            strokeColor: "rgba(220,220,220,1)",
            pointColor: "rgba(220,220,220,1)",
            pointStrokeColor: "#fff",
            data: chartBackend ? chartBackend.data : [65,59,90,81,56,55,40]
        };

        var dataset2 = {
            fillColor: "rgba(151,187,205,0.5)",
            strokeColor: "rgba(151,187,205,1)",
            pointColor: "rgba(151,187,205,1)",
            pointStrokeColor: "#fff",
            data: [28,48,40,19,96,27,100]
        };

        var chartObject = { labels: labels, datasets: [ dataset1, dataset2 ] };

        // 1) Try global function radar() first (unlikely for this Chart.qml)
        if (typeof radar === "function") {
            console.log("Found global function radar(). Calling radar(chartObject).")
            try {
                radar(chartObject);
                console.log("radar() call completed")
            } catch (e) {
                console.log("radar() threw:", e)
            }
            return;
        } else {
            console.log("No global radar() function found. Will try other ways.")
        }

        // 2) Try temporarily loading Chart.qml (in case it registers functions when evaluated)
        try {
            var tmpComp = Qt.createComponent("qrc:/charts/Chart.qml");
            if (tmpComp.status === Component.Ready) {
                var tmpInst = tmpComp.createObject(null, { visible: false });
                if (tmpInst !== null) {
                    console.log("Temporary Chart instance created to expose functions (hidden).");
                    if (typeof radar === "function") {
                        try {
                            radar(chartObject);
                            console.log("Called radar(chartObject) after loading temporary instance.");
                            tmpInst.destroy();
                            return;
                        } catch (e) {
                            console.log("radar() after temp load threw:", e);
                        }
                    }
                    tmpInst.destroy();
                } else {
                    console.log("Could not create temporary Chart instance.");
                }
            } else {
                console.log("tmpComp not ready:", tmpComp.errorString());
            }
        } catch (e) {
            console.log("Error while attempting temporary load:", e);
        }

        // 3) Fallback — create Chart.qml as a visual component and add it to chartArea
        var comp = Qt.createComponent("qrc:/charts/Chart.qml");
        console.log("component status:", comp.status, " error:", comp.errorString());
        if (comp.status === Component.Ready) {
            var inst = comp.createObject(chartArea, {
                "type": chartBackend ? chartBackend.type : "radar",
                "data": chartBackend ? chartBackend.data : [65,59,90,81,56,55,40]
            });
            if (inst === null) {
                console.log("Failed to create Chart instance (createObject returned null).")
            } else {
                // try anchors.fill first (works if Chart.qml's root supports anchors)
                try {
                    inst.anchors.fill = chartArea;
                } catch (e) {
                    // fallback to manual sizing and resize handlers
                    inst.x = 0;
                    inst.y = 0;
                    inst.width = chartArea.width;
                    inst.height = chartArea.height;
                    chartArea.onWidthChanged.connect(function() { inst.width = chartArea.width; });
                    chartArea.onHeightChanged.connect(function() { inst.height = chartArea.height; });
                }

                // ensure visible and on top
                inst.visible = true;
                inst.z = 1;

                // IMPORTANT: wait a short moment for the Canvas to become available,
                // then call inst.radar(chartObject). Using a tiny Timer is reliable.
                var t = Qt.createQmlObject('import QtQuick 2.12; Timer {}', chartArea);
                t.interval = 60; // 60 ms - small delay to let Canvas initialize
                t.repeat = false;
                t.triggered.connect(function() {
                    try {
                        if (typeof inst.radar === "function") {
                            console.log("Calling inst.radar(chartObject) to draw the radar (after delay).");
                            inst.radar(chartObject);
                            if (typeof inst.requestPaint === "function") inst.requestPaint();
                        } else {
                            console.log("inst.radar is not a function. Chart may not expose radar() on the instance.");
                        }
                    } catch (e) {
                        console.log("Error when calling inst.radar:", e);
                    }
                    // clean up timer object
                    t.destroy();
                });
                t.start();

                console.log("Chart instance created successfully and anchored/resized to chartArea.");
            }
        } else {
            console.log("Chart component not ready. comp.errorString():", comp.errorString())
        }
    }
}
