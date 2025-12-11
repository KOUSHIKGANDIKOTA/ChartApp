#include "ChartData.h"
#include <QFile>
#include <QTextStream>
#include <QVariantMap>
#include <QDebug>
#include <QtMath>
#include <QUrl>
#include <QRegExp>


//  Utility split functions
// Split but KEEP empty fields
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

// Split and skip empty fields
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




// Constructor: initialize dummy example

ChartData::ChartData(QObject *parent) : QObject(parent)
{
    // Default dummy labels
    m_labels = {"Eating","Drinking","Sleeping","Coding"};

    QVariantMap ds1; ds1["label"] = "Sample A"; ds1["data"] = QVariantList{65,59,90,81};
    QVariantMap ds2; ds2["label"] = "Sample B"; ds2["data"] = QVariantList{28,48,40,19};

    m_rawDatasets = {ds1, ds2};
    m_datasets    = m_rawDatasets;

    // default colors
    m_colors = {"#4CBAB6", "#C0C0C0", "#F28E2C", "#7FB3D5"};
}



// Per-axis normalization helper

static QVariantList normalizePerAxisHelper(
        const QVariantList &labels,
        const QVariantList &rawDatasets)
{
    int axes = labels.size();

    QVector<double> amin(axes,  1e300);
    QVector<double> amax(axes, -1e300);

    // Compute min-max for each axis
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

    // Fix invalid ranges
    for (int i = 0; i < axes; ++i)
    {
        if (amin[i] > amax[i])
        {
            amin[i] = 0;
            amax[i] = 1;
        }
        if (qFuzzyCompare(amin[i], amax[i]))
            amax[i] = amin[i] + 1.0;
    }

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

            double n = (v - amin[i]) / (amax[i] - amin[i]);
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

void ChartData::setData(const QVariantList &labels, const QVariantList &datasets)
{
    m_labels      = labels;
    m_rawDatasets = datasets;

    if (m_normalizePerAxis)
    {
        m_datasets = normalizePerAxisHelper(labels, datasets);
        m_minValue = 0;
        m_maxValue = 1;
        emit minMaxChanged();
    }
    else
    {
        m_datasets = datasets;

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




// Clear

void ChartData::clearData()
{
    m_labels.clear();
    m_rawDatasets.clear();
    m_datasets.clear();

    emit labelsChanged();
    emit datasetsChanged();
}




// Generic loader (CSV or TSV depending on delimiter)

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

    //Read header
    QString headerLine;

    while (!in.atEnd())
    {
        headerLine = in.readLine().trimmed();
        if (!headerLine.isEmpty())
            break;
    }

    if (headerLine.isEmpty())
    {
        qWarning() << "Header empty";
        return false;
    }

    QStringList headers = splitSkipEmpty(headerLine, delim);

    bool firstColumnIsLabel = false;

    if (!headers.isEmpty())
    {
        QString h0 = headers.first().toLower();

        if (h0.contains("label") ||
            h0.contains("name") ||
            h0.contains("case"))
        {
            firstColumnIsLabel = true;
            headers.removeFirst();
        }
    }

    QVariantList outLabels;
    for (auto &h : headers)
        outLabels.append(h);

    QVariantList outDatasets;

    // Read data rows
    while (!in.atEnd())
    {
        QString line = in.readLine();

        if (line.trimmed().isEmpty())
            continue;

        QStringList tokens = splitKeepEmpty(line, delim);
        for (QString &t : tokens) t = t.trimmed();

        QVariantMap dsMap;
        QVariantList vals;

        QString label = QString("Series %1").arg(outDatasets.size() + 1);
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
        qWarning() << "Parsed no data from file:" << path;
        return false;
    }

    m_lastCsvPath = path;
    setData(outLabels, outDatasets);

    return true;
}




// CSV wrapper
bool ChartData::loadCsv(const QString &filePathOrUrl)
{
    QString path = filePathOrUrl;

    QUrl url(path);
    if (url.isValid() && url.scheme().startsWith("file"))
        path = url.toLocalFile();

    return loadGeneric(path, ',');
}




// TSV wrapper (for Notepad exports)

bool ChartData::loadTsv(const QString &filePathOrUrl)
{
    QString path = filePathOrUrl;

    QUrl url(path);
    if (url.isValid() && url.scheme().startsWith("file"))
        path = url.toLocalFile();

    return loadGeneric(path, '\t');
}




// Reload last file

bool ChartData::reloadLastCsv()
{
    if (m_lastCsvPath.isEmpty())
        return false;

    if (m_lastCsvPath.endsWith(".tsv", Qt::CaseInsensitive) ||
        m_lastCsvPath.endsWith(".txt", Qt::CaseInsensitive))
    {
        return loadGeneric(m_lastCsvPath, '\t');
    }

    return loadGeneric(m_lastCsvPath, ',');
}




// Toggle per-axis normalization
void ChartData::setNormalizePerAxis(bool v)
{
    if (m_normalizePerAxis == v)
        return;

    m_normalizePerAxis = v;
    emit normalizePerAxisChanged();

    if (!m_labels.isEmpty() && !m_rawDatasets.isEmpty())
        setData(m_labels, m_rawDatasets);
}
