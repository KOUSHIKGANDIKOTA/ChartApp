#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "ChartData.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    ChartData chartData;
    chartData.setTitle("Radar Chart");
    chartData.setAutoscale(true);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("ChartData", &chartData);

    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
