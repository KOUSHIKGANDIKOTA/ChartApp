import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.12

Window {
    id: root
    width: 1200
    height: 820
    visible: true
    title: "Radar Chart (CSV + TSV)"

    // ================= FILE DIALOGS =================

    FileDialog {
        id: csvDialog
        title: "Open CSV"
        selectExisting: true
        nameFilters: ["CSV (*.csv)"]
        onAccepted: ChartData.loadCsv(fileUrl.toString())
    }

    FileDialog {
        id: tsvDialog
        title: "Open TSV / TXT"
        selectExisting: true
        nameFilters: ["TSV / TXT (*.tsv *.txt)"]
        onAccepted: ChartData.loadTsv(fileUrl.toString())
    }

    // ================= MAIN LAYOUT =================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ---------- Controls Row ----------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

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
                checked: ChartData.normalizePerAxis
                onCheckedChanged: ChartData.setNormalizePerAxis(checked)
            }
        }

        // ---------- Title ----------
        Text {
            text: ChartData.title
            font.pixelSize: 26
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        // ---------- Min / Max ----------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Text { text: "Global Min: " + ChartData.minValue.toFixed(3) }
            Text { text: "Global Max: " + ChartData.maxValue.toFixed(3) }
        }

        // ---------- Chart + Side Panel ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // ======= Radar Chart =======
            Loader {
                id: chartLoader
                Layout.preferredWidth: 800
                Layout.fillHeight: true
                source: "Chart.qml"
            }

            // ======= Side Info Panel =======
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 320
                color: "#F7F7F7"
                border.color: "#CCCCCC"
                radius: 6

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: ChartData.hoverDatasetLabel !== ""
                              ? "Dataset: " + ChartData.hoverDatasetLabel
                              : "Hover a region"
                        font.pixelSize: 18
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        height: 1
                        width: parent.width
                        color: "#CCCCCC"
                    }

                    // Axis values
                    Repeater {
                        model: ChartData.labels.length

                        delegate: Column {
                            spacing: 2

                            Text {
                                text: ChartData.labels[index]
                                font.bold: true
                            }

                            Text {
                                text:
                                    "Raw: " +
                                    (ChartData.hoverRawValues.length > index
                                        ? ChartData.hoverRawValues[index].toFixed(3)
                                        : "-")
                            }

                            Text {
                                text:
                                    "Norm: " +
                                    (ChartData.hoverNormValues.length > index
                                        ? ChartData.hoverNormValues[index].toFixed(3)
                                        : "-")
                            }

                            Text {
                                text:
                                    "Min: " + ChartData.axisMins[index].toFixed(3) +
                                    "  Max: " + ChartData.axisMaxs[index].toFixed(3)
                            }

                            Rectangle {
                                height: 1
                                width: parent.width
                                color: "#E0E0E0"
                                visible: index < ChartData.labels.length - 1
                            }
                        }
                    }
                }
            }
        }
    }
}
