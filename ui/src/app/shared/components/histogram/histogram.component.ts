import { Component, computed, input } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { HistogramData } from '../../models/model-run.interface';

/**
 * Pure presentation component that renders a pre-computed histogram
 * as responsive inline SVG with axes, labels, and hover tooltips.
 *
 * Theming: all stroke/fill values come from Material 3 system tokens
 * (`--mat-sys-primary`, `--mat-sys-on-surface-variant`,
 * `--mat-sys-outline-variant`) via CSS on the SVG elements, so the chart
 * tracks the light/dark theme automatically without any JS wiring.
 */
@Component({
  selector: 'app-histogram',
  standalone: true,
  imports: [DecimalPipe],
  template: `
    <svg [attr.viewBox]="viewBox" class="histogram-svg" preserveAspectRatio="xMidYMid meet"
         role="img" [attr.aria-label]="'Histogram with ' + data().counts.length + ' bins'">
      <!-- Y axis line -->
      <line [attr.x1]="margin.left" [attr.y1]="margin.top"
            [attr.x2]="margin.left" [attr.y2]="margin.top + chartHeight"
            class="axis-line" stroke-width="1" />

      <!-- X axis line -->
      <line [attr.x1]="margin.left" [attr.y1]="margin.top + chartHeight"
            [attr.x2]="margin.left + chartWidth" [attr.y2]="margin.top + chartHeight"
            class="axis-line" stroke-width="1" />

      <!-- Y axis ticks and grid lines -->
      @for (tick of yTicks(); track tick.value) {
        <text [attr.x]="margin.left - 8" [attr.y]="tick.y + 4"
              text-anchor="end" class="axis-label">{{ tick.value }}</text>
        <line [attr.x1]="margin.left" [attr.y1]="tick.y"
              [attr.x2]="margin.left + chartWidth" [attr.y2]="tick.y"
              class="grid-line" stroke-width="1" />
      }

      <!-- X axis ticks -->
      @for (tick of xTicks(); track tick.x) {
        <text [attr.x]="tick.x" [attr.y]="margin.top + chartHeight + 20"
              text-anchor="middle" class="axis-label">{{ tick.value | number:'1.1-1' }}</text>
      }

      <!-- Bars -->
      @for (bar of bars(); track bar.x) {
        <rect [attr.x]="bar.x" [attr.y]="bar.y"
              [attr.width]="bar.width" [attr.height]="bar.height"
              class="bar">
          <title>{{ bar.binStart | number:'1.2-2' }} – {{ bar.binEnd | number:'1.2-2' }}: {{ bar.count }}</title>
        </rect>
      }

      <!-- Axis labels -->
      <text [attr.x]="margin.left + chartWidth / 2" [attr.y]="height - 2"
            text-anchor="middle" class="axis-title">Value</text>
      <text [attr.x]="12" [attr.y]="margin.top + chartHeight / 2"
            text-anchor="middle" class="axis-title"
            [attr.transform]="'rotate(-90, 12, ' + (margin.top + chartHeight / 2) + ')'">Count</text>
    </svg>
  `,
  styles: [`
    :host {
      display: block;
    }

    .histogram-svg {
      width: 100%;
      max-width: 700px;
      height: auto;
    }

    .bar {
      fill: var(--mat-sys-primary);
      opacity: 0.85;
      transition: opacity 120ms ease;

      &:hover {
        opacity: 1;
      }
    }

    .axis-line {
      stroke: var(--mat-sys-outline-variant);
    }

    .grid-line {
      stroke: var(--mat-sys-outline-variant);
      opacity: 0.5;
    }

    .axis-label {
      font-size: 11px;
      fill: var(--mat-sys-on-surface-variant);
    }

    .axis-title {
      font-size: 12px;
      fill: var(--mat-sys-on-surface-variant);
      font-weight: 500;
    }
  `],
})
export class HistogramComponent {
  /** Pre-computed histogram data to render. */
  readonly data = input.required<HistogramData>();

  /** SVG canvas dimensions. */
  private readonly width = 600;
  readonly height = 300;
  readonly margin = { top: 20, right: 20, bottom: 40, left: 50 } as const;

  readonly chartWidth = this.width - this.margin.left - this.margin.right;
  readonly chartHeight = this.height - this.margin.top - this.margin.bottom;
  readonly viewBox = `0 0 ${this.width} ${this.height}`;

  /** Computed bar rectangles mapped from histogram counts. */
  readonly bars = computed(() => {
    const d = this.data();
    if (!d || d.counts.length === 0) return [];

    const maxCount = Math.max(...d.counts);
    const barWidth = this.chartWidth / d.counts.length;

    return d.counts.map((count, i) => ({
      x: this.margin.left + i * barWidth,
      y: this.margin.top + this.chartHeight - (maxCount > 0 ? (count / maxCount) * this.chartHeight : 0),
      width: Math.max(barWidth - 1, 1),
      height: maxCount > 0 ? (count / maxCount) * this.chartHeight : 0,
      count,
      binStart: d.binEdges[i],
      binEnd: d.binEdges[i + 1],
    }));
  });

  /** Y-axis ticks (5 evenly spaced from 0 to max count). */
  readonly yTicks = computed(() => {
    const d = this.data();
    if (!d || d.counts.length === 0) return [];
    const maxCount = Math.max(...d.counts);
    return [0, 0.25, 0.5, 0.75, 1].map(pct => ({
      value: Math.round(maxCount * pct),
      y: this.margin.top + this.chartHeight - pct * this.chartHeight,
    }));
  });

  /** X-axis ticks (up to 5 evenly spaced bin edge labels). */
  readonly xTicks = computed(() => {
    const d = this.data();
    if (!d || d.binEdges.length === 0) return [];
    const edges = d.binEdges;
    const step = Math.max(1, Math.floor(edges.length / 5));
    const ticks: Array<{ value: number; x: number }> = [];
    for (let i = 0; i < edges.length; i += step) {
      ticks.push({
        value: edges[i],
        x: this.margin.left + (i / (edges.length - 1)) * this.chartWidth,
      });
    }
    return ticks;
  });
}
