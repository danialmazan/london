import type { ElectionKey, LayerDefinition, ReportElection, SectionReport, SectionReportIndex, ValueFormat } from "./types";

const electionNames: Record<ElectionKey, string> = { general: "UK General Election 2024", local: "London borough elections 2022", mayor: "Mayor of London 2021", assembly: "London-wide Assembly ballot 2021" };
const partyNames: Record<string, string> = { labour: "Labour", conservative: "Conservative", liberal_democrat: "Liberal Democrats", green: "Green", reform: "Reform UK" };
const groups = {
  population: ["population_total", "population_density_km2", "under18_pct", "age65plus_pct", "population_change_5y_pct", "foreign_born_pct"],
  work: ["activity_rate_pct", "employment_rate_pct", "unemployment_rate_pct", "level4plus_pct", "low_no_qualifications_pct"],
  income: ["income_bhc_gbp", "income_ahc_gbp", "income_deprivation_rate", "idaci_rate", "idaopi_rate"],
};

export function sectionProperties(report: SectionReport, definition: LayerDefinition): Record<string, unknown> {
  const properties: Record<string, unknown> = { section_id: report.id, section_name: report.name, district: report.district };
  for (const [key, item] of Object.entries(report.metrics)) { properties[key] = item.value; properties[`${key}_percentile`] = item.percentile; }
  const key = definition.control?.election;
  if (key) {
    const election = report.elections[key];
    Object.assign(properties, { [`leader_${key}`]: election.leader, [`leader_key_${key}`]: election.leader?.toLowerCase().replaceAll(" ", "_") ?? null, [`lead_votes_${key}`]: election.leadVotes, [`lead_percent_${key}`]: election.leadPercent, [`lead_label_${key}`]: election.leadLabel, [`turnout_pct_${key}`]: election.turnoutPct, [`valid_votes_${key}`]: election.validVotes });
    for (const [party, share] of Object.entries(election.shares)) properties[`share_${party}_${key}`] = share;
  }
  return properties;
}

export function renderLondonElectionCard(): string {
  return `<div class="feature-header"><span class="feature-kicker">Election geography</span><h3>Choose an area on the map</h3><p>Results use their official native geography. Select a constituency or ward to inspect the leader, vote lead and turnout where published.</p></div>`;
}

export function renderSectionReport(index: SectionReportIndex, section: SectionReport): string {
  return `<article class="section-report-document">
    <header class="report-hero"><div><p class="report-overline">London small-area report · mixed official geographies</p><h2>${esc(section.name)}</h2><p class="report-id">LSOA21 ${esc(section.id)} · ${esc(section.district)}</p></div><div class="report-stamp"><span>London Atlas</span><strong>${esc(index.generatedAt.slice(0, 10))}</strong><small>danielalmazan.com</small></div></header>
    ${chapter("01", "Population", "LSOA21", groups.population.map(key => metric(section, key)).join(""))}
    ${chapter("02", "Education & work", "LSOA21 · Census 2021", groups.work.map(key => metric(section, key)).join(""))}
    ${chapter("03", "Income & deprivation", "MSOA21 income; LSOA21 deprivation", groups.income.map(key => metric(section, key)).join(""))}
    ${chapter("04", "Elections", "Constituency and ward results", `<div class="report-election-grid">${(["general", "local", "mayor", "assembly"] as ElectionKey[]).map(key => electionCard(section.elections[key], key)).join("")}</div>`)}
    ${chapter("05", "Geography crosswalk", "No values are downscaled between official units", `<dl class="report-geography-list">${Object.entries(section.geographies).map(([key, geo]) => `<div><dt>${esc(key)}</dt><dd>${geo.name ? `${esc(geo.name)} · ${esc(geo.id ?? "")}` : "No data"} <small>${esc(geo.vintage)}</small></dd></div>`).join("")}</dl>`)}
    <footer class="report-sources"><h3>Sources & interpretation</h3><p>Metrics retain their native published geography and vintage. MSOA income is not presented as an LSOA estimate. Missing or unpublished observations remain <strong>No data</strong>. Foreign citizenship and foreign-born change are not included.</p><p><strong>Domestic properties only.</strong> Construction age may be modelled where no direct source record is available.</p><ul>${index.references.map(r => `<li><a href="${esc(r.url)}">${esc(r.title)}</a> · ${esc(r.organisation)}<span>${esc(r.licence)} · retrieved ${esc(r.retrieved)}</span></li>`).join("")}</ul><p class="report-credit"><strong>danielalmazan.com</strong> · London Atlas</p></footer>
  </article>`;
}

function chapter(number: string, title: string, subtitle: string, body: string): string { return `<section class="report-chapter"><div class="report-chapter-heading"><p>${number}</p><div><h3>${esc(title)}</h3><span>${esc(subtitle)}</span></div></div><div class="report-metric-grid">${body}</div></section>`; }
function metric(section: SectionReport, key: string): string { const item = section.metrics[key]; if (!item) return ""; return `<article class="report-metric${item.value === null ? " is-missing" : ""}"><div class="report-metric-value"><h4>${esc(item.label)}</h4><strong>${formatValue(item.value, item.format)}</strong><span>${item.percentile === null ? "No percentile" : `${Math.round(item.percentile)}th percentile`} · ${esc(item.geography)} · ${esc(item.referenceDate)}</span></div><p>${esc(item.unit)}</p></article>`; }
function electionCard(item: ReportElection, key: ElectionKey): string { const shares = Object.entries(item.shares).filter(([, value]) => value !== null).sort((a, b) => (b[1] ?? 0) - (a[1] ?? 0)); return `<article class="report-election"><header><h4>${esc(electionNames[key])}</h4><span>${esc(item.geography)}</span></header><div class="election-turnout"><span>Lead</span><strong>${item.leadLabel ? esc(item.leadLabel) : "No data"}</strong><small>Turnout ${formatValue(item.turnoutPct, "percent")}</small></div><div class="election-comparisons">${shares.map(([party, value]) => `<div class="election-comparison"><div><strong>${esc(partyNames[party] ?? party)}</strong><span>${formatValue(value, "percent")}</span></div></div>`).join("")}</div></article>`; }
export function formatValue(value: number | null | undefined, format: ValueFormat, digits = 1): string { if (value === null || value === undefined || !Number.isFinite(value)) return "No data"; if (format === "integer") return Math.round(value).toLocaleString("en-GB"); if (format === "currency") return new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP", maximumFractionDigits: 0 }).format(value); if (format === "percent") return `${value.toFixed(digits)}%`; return value.toLocaleString("en-GB", { maximumFractionDigits: digits }); }
function esc(value: unknown): string { return String(value ?? "").replace(/[&<>'"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[c]!); }
