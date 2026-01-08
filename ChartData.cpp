#include "ChartData.h"
#include <QFile>
#include <QTextStream>
#include <QVariantMap>
#include <QDebug>
#include <QtMath>
#include <QUrl>


// Utility split functions


static QStringList splitKeepEmpty(const QString &line, const QChar &delim)
{
    QStringList parts;
    int start = 0;

    for (int i = 0; i < line.length(); ++i)
    {
        if (line.at(i) == delim)
        {
            parts.append(line.mid(start, i - start));
            start = i + 1;
        }
    }
    parts.append(line.mid(start));
    return parts;
}

static QStringList splitSkipEmpty(const QString &line, const QChar &delim)
{
    QStringList raw = splitKeepEmpty(line, delim);
    QStringList out;

    for (QString s : raw)
    {
        s = s.trimmed();
        if (!s.isEmpty())
            out.append(s);
    }
    return out;
}


// Constructor — dummy dataset


ChartData::ChartData(QObject *parent) : QObject(parent)
{
    m_labels = {"Eating","Drinking","Sleeping","Coding"};

    QVariantMap a; a["label"]="Sample A"; a["data"]=QVariantList{65,59,90,81};
    QVariantMap b; b["label"]="Sample B"; b["data"]=QVariantList{28,48,40,19};

    m_rawDatasets = {a,b};
    m_datasets    = m_rawDatasets;

    m_colors = {"#4CBAB6", "#C0C0C0", "#F28E2C", "#7FB3D5"};

    // compute per-axis ranges for dummy data
    setData(m_labels, m_rawDatasets);
}


// Helper: compute per-axis ranges


static void computeAxisRanges(
        const QVariantList &labels,
        const QVariantList &rawDatasets,
        QVariantList &axisMins,
        QVariantList &axisMaxs)
{
    int axes = labels.size();
    QVector<double> amin(axes,  1e300);
    QVector<double> amax(axes, -1e300);

    for (const QVariant &vd : rawDatasets)
    {
        QVariantMap map = vd.toMap();
        QVariantList vals = map["data"].toList();

        for (int i = 0; i < axes; ++i)
        {
            if (i < vals.size())
            {
                bool ok;
                double v = vals[i].toDouble(&ok);
                if (ok)
                {
                    amin[i] = qMin(amin[i], v);
                    amax[i] = qMax(amax[i], v);
                }
            }
        }
    }

    // fix invalid ranges
    for (int i = 0; i < axes; ++i)
    {
        if (amin[i] > amax[i])
        {
            amin[i] = 0;
            amax[i] = 1;
        }
        if (qFuzzyCompare(amin[i], amax[i]))   // avoid division by zero
            amax[i] = amin[i] + 1.0;
    }

    axisMins.clear();
    axisMaxs.clear();

    for (int i = 0; i < axes; ++i)
    {
        axisMins.append(amin[i]);
        axisMaxs.append(amax[i]);
    }
}


// Normalize dataset per axis


static QVariantList normalizePerAxisDatasets(
        const QVariantList &labels,
        const QVariantList &rawDatasets,
        const QVariantList &axisMins,
        const QVariantList &axisMaxs)
{
    int axes = labels.size();
    QVariantList out;

    for (const QVariant &vd : rawDatasets)
    {
        QVariantMap map = vd.toMap();
        QVariantList vals = map["data"].toList();
        QVariantList normVals;

        for (int i = 0; i < axes; ++i)
        {
            double v = 0;
            if (i < vals.size())
            {
                bool ok;
                v = vals[i].toDouble(&ok);
                if (!ok) v = 0;
            }

            double minA = axisMins[i].toDouble();
            double maxA = axisMaxs[i].toDouble();

            double n = (v - minA) / (maxA - minA);
            if (n < 0) n = 0;
            if (n > 1) n = 1;

            normVals.append(n);
        }

        QVariantMap newMap;
        newMap["label"] = map["label"];
        newMap["data"]  = normVals;

        out.append(newMap);
    }

    return out;
}


// setData (core function)


void ChartData::setData(const QVariantList &labels,
                        const QVariantList &datasets)
{
    m_labels      = labels;
    m_rawDatasets = datasets;

    // compute axis min/max
    computeAxisRanges(m_labels, m_rawDatasets, m_axisMins, m_axisMaxs);
    emit axisRangesChanged();

    if (m_normalizePerAxis)
    {
        m_datasets = normalizePerAxisDatasets(m_labels, m_rawDatasets,
                                              m_axisMins, m_axisMaxs);

        m_minValue = 0;
        m_maxValue = 1;
        emit minMaxChanged();
    }
    else
    {
        m_datasets = m_rawDatasets;

        if (m_autoscale)
        {
            double mn = 1e300;
            double mx = -1e300;

            for (const QVariant &vd : m_datasets)
            {
                QVariantList ds = vd.toMap()["data"].toList();
                for (auto v : ds)
                {
                    bool ok;
                    double x = v.toDouble(&ok);
                    if (ok)
                    {
                        mn = qMin(mn, x);
                        mx = qMax(mx, x);
                    }
                }
            }

            if (mn > mx)
            {
                mn = 0;
                mx = 1;
            }

            if (qFuzzyCompare(mn, mx))
                mx = mn + 1.0;

            m_minValue = mn;
            m_maxValue = mx;
            emit minMaxChanged();
        }
    }

    emit labelsChanged();
    emit datasetsChanged();
}


// Clear all data


void ChartData::clearData()
{
    m_labels.clear();
    m_rawDatasets.clear();
    m_datasets.clear();
    m_axisMins.clear();
    m_axisMaxs.clear();

    emit labelsChanged();
    emit datasetsChanged();
    emit axisRangesChanged();
}

// Generic CSV/TSV Loader


bool ChartData::loadGeneric(const QString &path, QChar delim)
{
    QFile f(path);
    if (!f.exists())
    {
        qWarning() << "File not found:" << path;
        return false;
    }
    if (!f.open(QFile::ReadOnly | QFile::Text))
    {
        qWarning() << "Failed to open:" << path;
        return false;
    }

    QTextStream in(&f);

    // header
    QString headerLine;
    while (!in.atEnd())
    {
        headerLine = in.readLine().trimmed();
        if (!headerLine.isEmpty())
            break;
    }

    if (headerLine.isEmpty())
    {
        qWarning() << "Header empty.";
        return false;
    }

    QStringList headers = splitSkipEmpty(headerLine, delim);

    bool firstColumnIsLabel = false;

    if (!headers.isEmpty())
    {
        QString h0 = headers.first().toLower();
        if (h0.contains("label") || h0.contains("name") || h0.contains("case"))
        {
            firstColumnIsLabel = true;
            headers.removeFirst();
        }
    }

    QVariantList outLabels;
    for (auto &h : headers)
        outLabels.append(h);

    QVariantList outDatasets;

    // rows
    while (!in.atEnd())
    {
        QString line = in.readLine();
        if (line.trimmed().isEmpty())
            continue;

        QStringList tokens = splitKeepEmpty(line, delim);
        for (QString &t : tokens) t = t.trimmed();

        QVariantMap dsMap;
        QVariantList vals;

        QString label = QString("Series %1").arg(outDatasets.size()+1);
        int start = 0;

        if (firstColumnIsLabel && tokens.size() > 0)
        {
            label = tokens[0];
            start = 1;
        }

        for (int i = start; i < tokens.size(); ++i)
        {
            bool ok;
            double v = tokens[i].toDouble(&ok);
            if (!ok) v = 0;
            vals.append(v);
        }

        dsMap["label"] = label;
        dsMap["data"]  = vals;

        outDatasets.append(dsMap);
    }

    if (outLabels.isEmpty() || outDatasets.isEmpty())
    {
        qWarning() << "Parsed no data.";
        return false;
    }

    m_lastCsvPath = path;
    setData(outLabels, outDatasets);
    return true;
}


// CSV Loader


bool ChartData::loadCsv(const QString &filePathOrUrl)
{
    QString path = filePathOrUrl;
    QUrl url(path);

    if (url.isValid() && url.scheme().startsWith("file"))
        path = url.toLocalFile();

    return loadGeneric(path, ',');
}


// TSV Loader


bool ChartData::loadTsv(const QString &filePathOrUrl)
{
    QString path = filePathOrUrl;
    QUrl url(path);

    if (url.isValid() && url.scheme().startsWith("file"))
        path = url.toLocalFile();

    return loadGeneric(path, '\t');
}


// Reload last CSV/TSV


bool ChartData::reloadLastCsv()
{
    if (m_lastCsvPath.isEmpty())
        return false;

    if (m_lastCsvPath.endsWith(".tsv", Qt::CaseInsensitive) ||
        m_lastCsvPath.endsWith(".txt", Qt::CaseInsensitive))
        return loadGeneric(m_lastCsvPath, '\t');

    return loadGeneric(m_lastCsvPath, ',');
}


// Toggle normalization


void ChartData::setNormalizePerAxis(bool v)
{
    if (m_normalizePerAxis == v)
        return;

    m_normalizePerAxis = v;
    emit normalizePerAxisChanged();

    if (!m_labels.isEmpty() && !m_rawDatasets.isEmpty())
        setData(m_labels, m_rawDatasets);
}
