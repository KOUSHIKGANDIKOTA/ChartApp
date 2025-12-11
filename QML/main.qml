import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.12

Window {
    id: root
    width: 1000
    height: 820
    visible: true
    title: "Radar Chart (CSV + TSV + Export PNG)"

    // CSV dialog
    FileDialog {
        id: csvDialog
        title: "Open CSV"
        selectExisting: true
        nameFilters: ["CSV (*.csv)"]
        onAccepted: ChartData.loadCsv(fileUrl.toString())
    }

    // TSV dialog
    FileDialog {
        id: tsvDialog
        title: "Open TSV / TXT"
        selectExisting: true
        nameFilters: ["TSV / TXT (*.tsv *.txt)"]
        onAccepted: ChartData.loadTsv(fileUrl.toString())
    }

    // Save PNG dialog (uses Save mode)
    FileDialog {
        id: saveDialog
        title: "Save chart as PNG"
        selectExisting: false
        folder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: ["PNG Image (*.png)"]
        onAccepted: {
            // fileUrl is a file:///... URL; convert to local path and trigger save
            var localPath = Qt.resolvedUrl(fileUrl).toLocalFile();
            if (!localPath || localPath.length === 0) {
                console.log("Invalid save path");
                return;
            }

            // Ensure the chart is painted, then grab image and save
            if (!chartLoader.item || !chartLoader.item.radarCanvas) {
                console.log("Chart not ready to export.");
                return;
            }

            // Ask Canvas to repaint to ensure up-to-date visual
            chartLoader.item.radarCanvas.requestPaint();

            // Small delay to give the Canvas time to paint
            saveWaitTimer.repeat = false;
            saveWaitTimer.start();

            // Save path is stored for the timer handler
            savePath = localPath;
        }
    }

    property string savePath: ""

    Timer {
        id: saveWaitTimer
        interval: 120   // milliseconds (enough for a single repaint; adjust if needed)
        repeat: false
        onTriggered: {
            // Use grabToImage on the Canvas. The GrabResult has saveToFile()
            var canvas = chartLoader.item.radarCanvas;
            if (!canvas) {
                console.log("No canvas to grab");
                return;
            }
            var grabResult = canvas.grabToImage(function(result) {
                if (!result) {
                    console.log("Grab failed");
                    return;
                }
                var ok = result.saveToFile(savePath);
                if (!ok) {
                    console.log("Failed to save PNG to", savePath);
                } else {
                    console.log("Saved chart PNG to", savePath);
                }
            });
            // note: grabToImage uses callback; no need to hold grabResult var
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Button {
                text: "Clear Chart"
                onClicked: ChartData.clearData()
            }
            Button {
                text: "Open CSV..."
                onClicked: csvDialog.open()
            }
            Button {
                text: "Open TSV..."
                onClicked: tsvDialog.open()
            }

            CheckBox {
                text: "Normalize per-axis"
                onCheckedChanged: ChartData.setNormalizePerAxis(checked)
            }
        }

        Text {
            text: ChartData.title
            font.pixelSize: 26
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter
            Text { text: "Min: " + ChartData.minValue.toFixed(3) }
            Text { text: "Max: " + ChartData.maxValue.toFixed(3) }
        }

        Loader {
            id: chartLoader
            anchors.horizontalCenter: parent.horizontalCenter
            source: "Chart.qml"
        }
    }
}
