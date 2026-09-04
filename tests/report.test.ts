import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { renderThemeSectionCard } from "../src/report";
import type { LayerManifest, SectionReportIndex } from "../src/types";

const read = <T>(path: string): T => JSON.parse(readFileSync(new URL(`../${path}`, import.meta.url), "utf8")) as T;
const manifest = read<LayerManifest>("public/data/layer-manifest.json");
const reports = read<SectionReportIndex>("public/data/section-reports.json");
const section = reports.sections.E01004731!;

describe("section cards", () => {
  it("shows the complete population theme without the red foreign-born disclaimer", () => {
    const definition = manifest.layers.find(layer => layer.id === "foreign-born")!;
    const html = renderThemeSectionCard(section, definition);
    expect(html).toContain("Resident population");
    expect(html).toContain("Foreign-born residents");
    expect(html).not.toContain("feature-data-note");
  });

  it("uses area and constituency in the heading and only the geography type below", () => {
    const definition = manifest.layers.find(layer => layer.id === "general-result")!;
    const html = renderThemeSectionCard(section, definition);
    expect(html).toContain("Westminster 020A – Cities of London and Westminster");
    expect(html).toContain("<p>Westminster constituency</p>");
    expect(html).not.toContain("Westminster · Westminster constituency");
  });
});
