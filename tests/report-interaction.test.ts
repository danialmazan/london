// @vitest-environment jsdom

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { bindDistributionCharts, chartXFromClientX, distributionPreviewText, percentileAtValue, valueFromChartX } from "../src/report-interaction";
import type { ReportDistribution, SectionReportIndex } from "../src/types";

const distribution: ReportDistribution = {
  label: "Population density", format: "integer", unit: "residents/km²",
  breaks: [0, 10, 20, 30, 40], counts: [2, 3, 3, 2], observationCount: 10,
  min: 10, max: 30, percentileValues: [10, 20, 30], percentileRanks: [0, 50, 100],
};

describe("distribution exploration", () => {
  it("maps chart positions and interpolates percentiles", () => {
    expect(chartXFromClientX(150, 20, 260)).toBe(130);
    expect(valueFromChartX(130, 0, 40)).toBe(20);
    expect(percentileAtValue(distribution, 15)).toBe(25);
    expect(distributionPreviewText(distribution, 18.4)).toBe("42nd percentile · 18");
  });
});

describe("distribution pointer interactions", () => {
  beforeEach(() => Object.defineProperty(window, "matchMedia", { configurable: true, value: () => ({ matches: true }) }));
  afterEach(() => { document.body.innerHTML = ""; });

  it("updates while dragging and restores on release", () => {
    document.body.innerHTML = `<div class="distribution-chart-shell"><svg class="distribution-chart" data-metric="test" data-low="0" data-high="40" data-original-x="130" data-original-value="20"><line class="distribution-marker" x1="130" x2="130"></line><circle class="distribution-dot" cx="130"></circle></svg><button class="distribution-drag-handle"></button><output class="distribution-preview" hidden></output></div>`;
    const container = document.body.firstElementChild as HTMLElement;
    const chart = container.querySelector("svg")!;
    const hit = container.querySelector("button")!;
    vi.spyOn(chart, "getBoundingClientRect").mockReturnValue({ left: 0, top: 0, width: 260, height: 68, right: 260, bottom: 68, x: 0, y: 0, toJSON: () => ({}) });
    Object.defineProperties(hit, { setPointerCapture: { configurable: true, value: vi.fn() }, hasPointerCapture: { configurable: true, value: vi.fn(() => false) }, releasePointerCapture: { configurable: true, value: vi.fn() } });
    const cleanup = bindDistributionCharts(container, { distributions: { test: distribution } } as unknown as SectionReportIndex);
    hit.dispatchEvent(pointerEvent("pointerdown", 130));
    hit.dispatchEvent(pointerEvent("pointermove", 195));
    expect(container.querySelector("line")!.getAttribute("x1")).toBe("195.00");
    expect(container.querySelector("output")!.hidden).toBe(false);
    hit.dispatchEvent(pointerEvent("pointerup", 195));
    expect(container.querySelector("line")!.getAttribute("x1")).toBe("130.00");
    cleanup();
  });
});

function pointerEvent(type: string, clientX: number): Event {
  const event = new Event(type, { bubbles: true, cancelable: true });
  for (const [key, value] of Object.entries({ button: 0, pointerId: 7, pointerType: "touch", clientX })) Object.defineProperty(event, key, { configurable: true, value });
  return event;
}
