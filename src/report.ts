import { renderFeatureActions } from "./feature-actions";
import type { ElectionKey, LayerDefinition, ReportElection, ReportMetricValue, SectionReport, SectionReportIndex, ValueFormat } from "./types";

const electionNames: Record<ElectionKey, string> = { general: "UK General Election 2024", local: "London borough elections 2022", mayor: "Mayor of London 2021", assembly: "London-wide Assembly ballot 2021" };
const groups = {
  population: ["population_total", "population_density_km2", "under18_pct", "age65plus_pct", "population_change_5y_pct", "foreign_born_pct"],
  work: ["activity_rate_pct", "employment_rate_pct", "unemployment_rate_pct", "level4plus_pct", "low_no_qualifications_pct"],
  income: ["income_bhc_gbp", "income_ahc_gbp", "income_deprivation_rate", "idaci_rate", "idaopi_rate"],
};

export function renderThemeSectionCard(section: SectionReport, definition: LayerDefinition): string {
  const header = (title = section.name, context = `${section.district} · LSOA21 ${section.id}`) => `<div class="feature-header feature-header--area"><div class="feature-header-copy"><h3>${esc(title)}</h3><p>${esc(context)}</p></div><button class="clear-area-button" type="button" aria-label="Clear selected area"><svg class="close-icon" viewBox="0 0 16 16" aria-hidden="true"><use href="#icon-close" /></svg></button></div>`;
  if (definition.group === "elections") {
    const key = definition.control?.election ?? "general";
    const item = section.elections[key];
    const nativeName = item.areaName ?? "No matching published result";
    return `${header(`${section.name} – ${nativeName}`, electionGeographyLabel(key))}${electionSummary(item)}${key === "local" && !item.areaName ? cityElectionNote() : ""}${renderFeatureActions(definition.group, true)}`;
  }
  const keys = definition.group === "population" ? groups.population : definition.group === "education-work" ? groups.work : groups.income;
  const fields = keys.map((key) => compactMetric(section.metrics[key])).join("");
  const note = definition.group === "income"
      ? `<aside class="feature-data-note"><strong>Mixed geography</strong><p>Income figures use the containing MSOA21; deprivation figures use this LSOA21. No values are downscaled.</p></aside>`
      : "";
  return `${header()}<dl class="feature-grid">${fields}</dl>${note}${renderFeatureActions(definition.group, true)}`;
}

export function renderLondonElectionCard(): string {
  return `<div class="feature-header"><span class="feature-kicker">Election geography</span><h3>Choose an area on the map</h3><p>Results remain on their official constituency or ward geography. Selecting a result also identifies the containing LSOA.</p></div>`;
}

export function renderSectionReport(index: SectionReportIndex, section: SectionReport): string {
  return `<article class="section-report-document">
    <header class="report-hero"><div><p class="report-overline">London small-area report · mixed official geographies</p><h2>${esc(section.name)}</h2><p class="report-id">LSOA21 ${esc(section.id)} · ${esc(section.district)}</p></div><div class="report-stamp"><span>London Atlas</span><strong>${esc(index.generatedAt.slice(0, 10))}</strong><small>danielalmazan.com</small></div></header>
    ${chapter("01", "Population", "LSOA21", groups.population.map(key => reportMetric(index, section.metrics[key], key)).join(""))}
    ${chapter("02", "Education & work", "LSOA21 · Census 2021", groups.work.map(key => reportMetric(index, section.metrics[key], key)).join(""))}
    ${chapter("03", "Income & deprivation", "MSOA21 income; LSOA21 deprivation", groups.income.map(key => reportMetric(index, section.metrics[key], key)).join(""))}
    ${chapter("04", "Elections", "Constituency and ward results", `<div class="report-election-grid">${(["general", "local", "mayor", "assembly"] as ElectionKey[]).map(key => electionCard(section.elections[key], key)).join("")}</div>${!section.elections.local.areaName ? cityElectionNote() : ""}`)}
    ${chapter("05", "Geography crosswalk", "No values are downscaled between official units", `<dl class="report-geography-list">${Object.entries(section.geographies).map(([key, geo]) => `<div><dt>${esc(geographyLabel(key))}</dt><dd><strong>${geo.name ? esc(geo.name) : "No data"}</strong>${geo.id ? `<span>${esc(geo.id)}</span>` : ""}<small>${esc(geo.vintage)}</small></dd></div>`).join("")}</dl>`)}
    <footer class="report-sources"><h3>Sources & interpretation</h3><p>Percentiles and histograms compare valid observations on the metric's published geography. A higher percentile means a higher raw value, not necessarily a better outcome. Missing observations remain <strong>No data</strong>.</p><p>Foreign-born means born outside the United Kingdom and uses all Census 2021 usual residents as the denominator. MSOA income is not presented as an LSOA estimate.</p><p><strong>Domestic properties only.</strong> Construction year is the modal LBSM2 band for each matched building and may be modelled where no direct record is available.</p><ul>${index.references.map(r => `<li><a href="${esc(r.url)}">${esc(r.title)}</a> · ${esc(r.organisation)}<span>${esc(r.licence)} · retrieved ${esc(r.retrieved)}</span></li>`).join("")}</ul><p class="report-credit"><strong>danielalmazan.com</strong> · London Atlas</p></footer>
  </article>`;
}

function chapter(number: string, title: string, subtitle: string, body: string): string { return `<section class="report-chapter"><div class="report-chapter-heading"><p>${number}</p><div><h3>${esc(title)}</h3><span>${esc(subtitle)}</span></div></div><div class="report-metric-grid">${body}</div></section>`; }

function compactMetric(item: ReportMetricValue | undefined): string {
  if (!item) return "";
  const percentile = item.percentile === null ? "" : ` (${ordinal(Math.round(item.percentile))} perc.)`;
  return `<div class="feature-stat"><dt>${esc(item.label)}</dt><dd>${esc(formatValue(item.value, item.format))}${esc(percentile)}</dd></div>`;
}

function reportMetric(index: SectionReportIndex, item: ReportMetricValue | undefined, metric: string): string {
  if (!item) return "";
  const value = item.value;
  const distribution = index.distributions[metric];
  const percentile = item.percentile === null ? "No percentile" : `${ordinal(Math.round(item.percentile))} percentile`;
  const sample = distribution ? ` · n=${distribution.observationCount.toLocaleString("en-GB")}` : "";
  return `<article class="report-metric${value === null ? " is-missing" : ""}"><div class="report-metric-value"><h4>${esc(item.label)}</h4><strong>${esc(formatValue(value, item.format))}</strong><span>${esc(percentile)}${sample}</span>${item.note ? `<small>${esc(item.note)}</small>` : ""}</div>${value === null || !distribution ? noDataChart(item) : distributionChart(distribution, item, value, metric)}</article>`;
}

function distributionChart(distribution: SectionReportIndex["distributions"][string], item: ReportMetricValue, value: number, metric: string): string {
  const width = 260, height = 68, base = 52, maximum = Math.max(...distribution.counts, 1);
  const barWidth = width / Math.max(1, distribution.counts.length);
  const bars = distribution.counts.map((count, index) => { const h = Math.max(2, count / maximum * 38); return `<rect x="${(index * barWidth + 2).toFixed(1)}" y="${(base - h).toFixed(1)}" width="${Math.max(2, barWidth - 4).toFixed(1)}" height="${h.toFixed(1)}" rx="2" />`; }).join("");
  const low = distribution.breaks[0] ?? distribution.min ?? 0, high = distribution.breaks.at(-1) ?? distribution.max ?? low + 1;
  const x = Math.max(4, Math.min(width - 4, ((value - low) / Math.max(1e-9, high - low)) * width));
  const previewId = `distribution-preview-${metric}`;
  const valueText = formatValue(value, item.format);
  return `<div class="distribution-chart-shell"><svg class="distribution-chart" viewBox="0 0 ${width} ${height}" role="img" aria-label="Distribution of ${esc(item.label)} across ${distribution.observationCount} areas" data-metric="${esc(metric)}" data-low="${low}" data-high="${high}" data-original-x="${x.toFixed(2)}" data-original-value="${value}"><g class="distribution-bars">${bars}</g><line class="distribution-marker" x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="5" y2="57"/><circle class="distribution-dot" cx="${x.toFixed(1)}" cy="7" r="4"/><text x="0" y="66">${esc(formatValue(low, item.format))}</text><text x="${width}" y="66" text-anchor="end">${esc(formatValue(high, item.format))}</text></svg><button class="distribution-drag-handle" type="button" role="slider" style="left:${((x / width) * 100).toFixed(4)}%" aria-label="Explore ${esc(item.label)} distribution. Hold and drag, or use the arrow keys." aria-valuemin="${low}" aria-valuemax="${high}" aria-valuenow="${value}" aria-valuetext="${esc(`${item.percentile === null ? "Unknown" : ordinal(Math.round(item.percentile))} percentile · ${valueText}`)}" aria-describedby="${previewId}"></button><output id="${previewId}" class="distribution-preview" hidden></output></div>`;
}

function noDataChart(item: ReportMetricValue): string { return `<div class="distribution-empty" role="img" aria-label="No published value for ${esc(item.label)}"><span></span><p>Not published for this area</p><span></span></div>`; }
function electionSummary(item: ReportElection): string { return `<div class="election-card-summary"><div class="election-turnout"><span>Lead</span><strong>${item.leadLabel ? esc(item.leadLabel) : "No data"}</strong><small>Turnout ${formatValue(item.turnoutPct, "percent")}</small></div>${electionRows(item)}</div>`; }
function electionCard(item: ReportElection, key: ElectionKey): string { return `<article class="report-election"><header><h4>${esc(electionNames[key])}</h4><span>${esc(item.areaName ?? item.geography)}</span></header>${electionSummary(item)}</article>`; }
function electionRows(item: ReportElection): string {
  const shares = Object.entries(item.shares).filter(([, value]) => value !== null && value > 0).sort((a, b) => (b[1] ?? 0) - (a[1] ?? 0)).slice(0, 5);
  if (!shares.length) return `<p class="report-no-data">No published result for this area.</p>`;
  return `<div class="election-comparisons">${shares.map(([party, value]) => `<div class="election-comparison"><div><i style="background:${item.shareColours[party] ?? "#8A6F8F"}"></i><strong>${esc(item.shareLabels[party] ?? party)}</strong><span>${formatValue(value, "percent")}</span></div><div class="comparison-track"><i style="width:${Math.min(100, (value ?? 0) / 60 * 100).toFixed(1)}%;background:${item.shareColours[party] ?? "#8A6F8F"}"></i></div></div>`).join("")}</div>`;
}
function cityElectionNote(): string { return `<aside class="report-data-note"><strong>City of London</strong><p>The 2022 GLA borough-results workbook does not cover the City's separate Common Council elections, so these wards remain No data.</p></aside>`; }
function electionGeographyLabel(key: ElectionKey): string { return key === "general" ? "Westminster constituency" : "Electoral ward"; }
function geographyLabel(key: string): string { return ({ lsoa: "LSOA21", msoa: "MSOA21", ward2022: "Electoral ward 2022", ward2021: "Electoral ward 2021", constituency: "Westminster constituency 2024" } as Record<string, string>)[key] ?? key; }

export function formatValue(value: number | null | undefined, format: ValueFormat, digits = 1): string {
  if (value === null || value === undefined || !Number.isFinite(value)) return "No data";
  if (format === "integer") return Math.round(value).toLocaleString("en-GB");
  if (format === "currency") return new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP", maximumFractionDigits: 0 }).format(value);
  if (format === "percent") return `${value.toFixed(digits)}%`;
  return value.toLocaleString("en-GB", { maximumFractionDigits: digits });
}
export function ordinal(value: number): string { const mod100 = value % 100; if (mod100 >= 11 && mod100 <= 13) return `${value}th`; return `${value}${value % 10 === 1 ? "st" : value % 10 === 2 ? "nd" : value % 10 === 3 ? "rd" : "th"}`; }
function esc(value: unknown): string { return String(value ?? "").replace(/[&<>'"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[c]!); }
