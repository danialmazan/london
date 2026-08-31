import type { LayerGroup } from "./types";

export function renderFeatureActions(group: LayerGroup, isSection: boolean): string {
  const actions: string[] = [];
  if (isSection) {
    actions.push('<button class="open-section-report report-link-button" type="button">See full report</button>');
  }
  if (group === "elections" && isSection) {
    actions.push('<button class="back-to-election quiet-link-button" type="button">Back to election overview</button>');
  }
  if (!actions.length) return "";
  return `<div class="feature-actions">${actions.join("")}</div>`;
}
