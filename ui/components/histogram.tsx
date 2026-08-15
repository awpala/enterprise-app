import type { HistogramData } from '@/lib/types';

export function Histogram({ data }: { readonly data: HistogramData }) {
  const width = 640;
  const height = 280;
  const margin = { top: 16, right: 16, bottom: 36, left: 46 };
  const chartWidth = width - margin.left - margin.right;
  const chartHeight = height - margin.top - margin.bottom;
  const max = Math.max(...data.counts, 1);
  const barWidth = chartWidth / Math.max(data.counts.length, 1);

  return (
    <svg className="histogram" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={`Histogram with ${data.counts.length} bins`}>
      <line className="chart-axis" x1={margin.left} y1={margin.top} x2={margin.left} y2={margin.top + chartHeight} />
      <line className="chart-axis" x1={margin.left} y1={margin.top + chartHeight} x2={margin.left + chartWidth} y2={margin.top + chartHeight} />
      {data.counts.map((count, index) => {
        const barHeight = count / max * chartHeight;
        return (
          <rect
            className="chart-bar"
            key={`${data.binEdges[index]}-${index}`}
            x={margin.left + index * barWidth}
            y={margin.top + chartHeight - barHeight}
            width={Math.max(barWidth - 1, 1)}
            height={barHeight}
          >
            <title>{data.binEdges[index]?.toFixed(2)} – {data.binEdges[index + 1]?.toFixed(2)}: {count}</title>
          </rect>
        );
      })}
      <text className="chart-label" x={width / 2} y={height - 4} textAnchor="middle">Value</text>
      <text className="chart-label" x={14} y={height / 2} textAnchor="middle" transform={`rotate(-90 14 ${height / 2})`}>Count</text>
    </svg>
  );
}
