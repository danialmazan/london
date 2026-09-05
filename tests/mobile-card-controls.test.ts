import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const index = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const main = readFileSync(new URL("../src/main.ts", import.meta.url), "utf8");

describe("mobile area-card controls", () => {
  it("uses a labelled downward chevron for minimise without clearing selection", () => {
    expect(index).toContain('class="sheet-collapse"');
    expect(index).toContain('aria-label="Minimise map panel"');
    expect(index).toContain('<use href="#icon-chevron-down" />');
    expect(main).toContain('sheetClose.addEventListener("click", () => setSheetOpen(false))');
  });

  it("clears the selected area and returns to the layer menu from the card action", () => {
    expect(main).toMatch(/\.clear-area-button[\s\S]*clearSelectedSection\(\);[\s\S]*renderEmptyFeaturePanel\(\);[\s\S]*setMobilePanel\(true, "layers"\)/);
  });

  it("contains no legacy user-facing section copy", () => {
    for (const legacyCopy of [
      "Section details",
      "section details",
      "census section",
      "census-section",
      "Share section",
      "this section",
      "Section + layer",
    ]) {
      expect(main).not.toContain(legacyCopy);
      expect(index).not.toContain(legacyCopy);
    }
  });
});
