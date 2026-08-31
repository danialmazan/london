import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import type { LayerManifest, SectionReportIndex } from "../src/types";
const read = <T>(path: string): T => JSON.parse(readFileSync(new URL(`../${path}`, import.meta.url), "utf8")) as T;

describe("London atlas generated data", () => {
  const manifest = read<LayerManifest>("public/data/layer-manifest.json");
  const reports = read<SectionReportIndex>("public/data/section-reports.json");
  it("publishes the agreed layer catalogue and exclusions", () => {
    expect(manifest.layers).toHaveLength(62);
    const ids = manifest.layers.map(layer => layer.id);
    expect(ids).toEqual(expect.arrayContaining(["foreign-born", "income-bhc", "income-ahc", "general-lead", "local-lead", "mayor-lead", "assembly-lead", "domestic-property-age"]));
    expect(ids.join(" ")).not.toMatch(/foreign-citizenship|foreign-born-change|left-right|mayor-2024|assembly-2024/);
  });
  it("uses array source IDs and preserves native geographies", () => {
    expect(manifest.layers.every(layer => Array.isArray(layer.sourceIds))).toBe(true);
    expect(manifest.layers.find(layer => layer.id === "income-bhc")?.geography).toBe("MSOA21");
    expect(manifest.layers.find(layer => layer.id === "foreign-born")?.geography).toBe("LSOA21");
  });
  it("publishes 4,994 mixed-geography LSOA reports", () => {
    expect(Object.keys(reports.sections)).toHaveLength(4994);
    const report = Object.values(reports.sections)[0]!;
    expect(report.id).toMatch(/^E010\d{5}$/);
    expect(Object.keys(report.elections)).toEqual(["general", "local", "mayor", "assembly"]);
    expect(report.metrics.foreign_born_pct?.geography).toBe("LSOA21");
    expect(report.metrics.income_bhc_gbp?.geography).toBe("MSOA21");
  });
});
