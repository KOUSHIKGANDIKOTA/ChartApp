#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>

class ChartData : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList labels READ labels NOTIFY labelsChanged)
    Q_PROPERTY(QVariantList datasets READ datasets NOTIFY datasetsChanged)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(double minValue READ minValue NOTIFY minMaxChanged)
    Q_PROPERTY(double maxValue READ maxValue NOTIFY minMaxChanged)
    Q_PROPERTY(bool autoscale READ autoscale WRITE setAutoscale NOTIFY autoscaleChanged)
    Q_PROPERTY(bool normalizePerAxis READ normalizePerAxis WRITE setNormalizePerAxis NOTIFY normalizePerAxisChanged)
    Q_PROPERTY(QVariantList colors READ colors WRITE setColors NOTIFY colorsChanged)

public:
    explicit ChartData(QObject *parent = nullptr);

    QVariantList labels() const { return m_labels; }
    QVariantList datasets() const { return m_datasets; }
    QString title() const { return m_title; }
    double minValue() const { return m_minValue; }
    double maxValue() const { return m_maxValue; }
    bool autoscale() const { return m_autoscale; }
    bool normalizePerAxis() const { return m_normalizePerAxis; }
    QVariantList colors() const { return m_colors; }

    Q_INVOKABLE void setData(const QVariantList &labels, const QVariantList &datasets);
    Q_INVOKABLE void clearData();

    // File-loading API
    Q_INVOKABLE bool loadCsv(const QString &filePathOrUrl);
    Q_INVOKABLE bool loadTsv(const QString &filePathOrUrl);
    Q_INVOKABLE bool reloadLastCsv();

    Q_INVOKABLE void setNormalizePerAxis(bool v);

    Q_INVOKABLE void setMinValue(double v) { m_minValue = v; emit minMaxChanged(); }
    Q_INVOKABLE void setMaxValue(double v) { m_maxValue = v; emit minMaxChanged(); }

    void setTitle(const QString &t) { m_title = t; emit titleChanged(); }
    void setAutoscale(bool a) { m_autoscale = a; emit autoscaleChanged(); }
    void setColors(const QVariantList &c) { m_colors = c; emit colorsChanged(); }

signals:
    void labelsChanged();
    void datasetsChanged();
    void titleChanged();
    void minMaxChanged();
    void autoscaleChanged();
    void normalizePerAxisChanged();
    void colorsChanged();

private:
    QVariantList m_labels;
    QVariantList m_rawDatasets;
    QVariantList m_datasets;
    QString m_title;

    double m_minValue = 0.0;
    double m_maxValue = 100.0;
    bool m_autoscale = false;
    bool m_normalizePerAxis = false;

    QVariantList m_colors;
    QString m_lastCsvPath;

    bool loadGeneric(const QString &path, QChar delim);
};
