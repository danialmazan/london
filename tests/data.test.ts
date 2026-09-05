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
    expect(manifest.defaultLayer).toBe("population-density");
    expect(manifest.layers.find(layer => layer.id === "population-density")?.palette).toEqual(["#440154", "#414487", "#2a788e", "#22a884", "#7ad151", "#fde725"]);
    expect(manifest.layers.find(layer => layer.id === "domestic-property-age")?.kind).toBe("fill");
    expect(manifest.layers.find(layer => layer.id === "domestic-property-age")?.palette).toEqual(["#184e77", "#52b69a", "#d9ed92", "#f9c74f", "#f9844a", "#c1121f"]);
    expect(manifest.layers.find(layer => layer.id === "population-total")?.kind).toBe("dot-density");
    expect(manifest.layers.find(layer => layer.id === "population-total")?.dotValue).toBe(25);
    expect(manifest.layers.find(layer => layer.id === "general-labour")?.palette.at(-1)).toBe("#E4003B");
  });
  it("shows every rail and Santander stop layer from the same zoom", () => {
    const stops = manifest.layers.filter(layer => layer.kind === "transport-stop" && layer.control?.transportMode !== "bus");
    expect(stops.length).toBeGreaterThan(0);
    expect(stops.every(layer => layer.minzoom === 7)).toBe(true);
  });
  it("publishes 4,994 mixed-geography LSOA reports", () => {
    expect(Object.keys(reports.sections)).toHaveLength(4994);
    const report = Object.values(reports.sections)[0]!;
    expect(report.id).toMatch(/^E010\d{5}$/);
    expect(Object.keys(report.elections)).toEqual(["general", "local", "mayor", "assembly"]);
    expect(report.metrics.foreign_born_pct?.geography).toBe("LSOA21");
    expect(report.metrics.income_bhc_gbp?.geography).toBe("MSOA21");
    expect(reports.distributions.population_density_km2?.observationCount).toBe(4994);
    expect(report.elections.general.areaName).toBeTruthy();
    expect(report.elections.general.shareLabels.independent).toBe("Independent");
  });
  it("keeps candidates and smaller parties visible in election comparisons", () => {
    const islington = Object.values(reports.sections).find(report => report.elections.general.areaName === "Islington North");
    expect(islington).toBeTruthy();
    expect(islington?.elections.general.leader).toBe("Independent");
    expect(islington?.elections.general.shares.independent).toBeCloseTo(49.21846, 4);
    expect(islington?.elections.general.shares.labour).toBeCloseTo(34.43048, 4);
    expect(Object.values(reports.sections).some(report => report.elections.local.leader === "Aspire" && (report.elections.local.shares.aspire ?? 0) > 0)).toBe(true);
  });
  it("publishes the official road-search index and fixed population-change buckets", () => {
    const addresses = read<{ records: Array<[string, string, string, number, number]> }>("public/data/addresses.json");
    expect(addresses.records.length).toBeGreaterThan(50_000);
    expect(addresses.records.some(record => record[1] === "Yalding Road")).toBe(true);
    expect(manifest.layers.find(layer => layer.id === "population-change-5y")?.breaks.slice(1, -1)).toEqual([-8, -4, -1.5, 1.5, 4, 8]);
  });
  it("keeps the verified Brent 019D Census denominator transparent", () => {
    const brent = reports.sections.E01000633!;
    expect(brent.metrics.foreign_born_pct?.value).toBeCloseTo(71.66348, 4);
    expect(brent.metrics.foreign_born_pct?.note).toBe("1,874 of 2,615 usual residents");
    expect(brent.elections.general.areaName).toBe("Brent West");
  });
});
