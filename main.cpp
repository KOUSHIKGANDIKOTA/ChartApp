#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "ChartData.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Required for FileDialog / QSettings (prevents warnings)
    QCoreApplication::setOrganizationName("LOGEfuelES");
    QCoreApplication::setOrganizationDomain("logefueles.com");
    QCoreApplication::setApplicationName("RadarChartApp");

    // Backend data model
    ChartData chartData;

    // Keep original behavior
    chartData.setTitle("Radar Chart");
    chartData.setAutoscale(false);

    // NEW: default normalization ON (as requested)
    chartData.setNormalizePerAxis(true);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("ChartData", &chartData);

    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
