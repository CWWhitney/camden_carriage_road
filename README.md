# camden_carriage_road: one decision, many ontologies (Camden to the Snow Bowl)

A collection of causal diagrams (DAGs) for a single decision: **should a
separated carriage-road bike path be built from downtown Camden, Maine to the
Camden Snow Bowl, instead of relying on Hosmer Pond Road?** Each stakeholder
group gets its own DAG, input table and outcome function, reflecting its own
ontology and values. They combine into one `decisionSupport` Monte Carlo model
and a Keeney-style bubble matrix.

Start with **[GAME_PLAN.md](GAME_PLAN.md)** for the idea, phases and open questions. The plain-language blog
is `docs/index.html` and the technical vignette `vignettes/camden_carriage_road.Rmd` (see *Reports* below).

The Snow Bowl is town-owned (a Town special revenue fund), so it is part of the Town ontology and the Town
player, not a separate one.

> **All input ranges are placeholders** invented so the pipeline runs. They are
> flagged as such in every input table. The only cited number is the carbon price range in the NPV
> Pareto view (`R/exchange_rates.R`, `bib/references.bib`, checked against Crossref). Replace the rest
> with measured or elicited values before drawing any conclusion.

## Run it

```bash
Rscript run_all.R        # 5000 MC runs; pass a number to change, e.g. Rscript run_all.R 1000
```

Needs R packages `decisionSupport`, `dagitty`, `ggplot2`.

It validates each DAG against its inputs and outcome function, then runs the whole analysis twice, once per
liability scenario (`protected` and `exposed`, see `GAME_PLAN.md` section 10), and writes:

| Output | What |
|---|---|
| `inputs/<group>_inputs.csv`, `inputs/shared_inputs.csv`, `inputs/all_inputs.csv` | estimate tables for `decisionSupport` |
| `outputs/dags/<group>.png` | one DAG picture per stakeholder |
| `outputs/liability_<scenario>/value_summary.csv` | median, 90% interval, P(>0), certainty, relative size per stakeholder x value x option |
| `outputs/liability_<scenario>/keeney_bubble_matrix.png` | the bubble matrix |
| `outputs/liability_<scenario>/welfare_heatmap.png`, `pareto_landowners_vs_others.png`, `pareto_summary.csv` | Stage 1 welfare index per group, Pareto efficiency and frontier |
| `outputs/liability_<scenario>/welfare_heatmap_npv.png`, `pareto_landowners_vs_others_npv.png`, `pareto_summary_npv.csv` | the same on within-group NPV (exchange rates and their sources in `R/exchange_rates.R`) |
| `outputs/liability_<scenario>/game_voluntary_*` and `game_binding_*` (CSVs and plots), `game_mechanism_comparison.csv`, `mechanism_design_grid.*` | Stage 2: equilibria of the three-player game, sequential outcomes, welfare of all groups, sensitivity to the Town's weight on residents, binding terms vs grants |
| `outputs/liability_<scenario>/mc_results.rds` | raw MC output |
| `outputs/mechanism_comparison.png`, `outputs/mechanism_design_grid_both_scenarios.csv` | does binding cost-sharing make a path stable, and which terms leave all three players better off |
| `outputs/liability_comparison.png`, `outputs/liability_comparison_*.csv` | protected vs exposed: landowners' net position by option, and the game outcome by scenario |

## Layout

```
stakeholders/NN_name.R   one file per ontology: DAG + inputs + values + outcome function
R/shared_decision.R      options (parameter bundles) and the shared physical layer (land, trees, trips, costs)
R/helpers.R              E(), V(), make_dag(), validation, DAG plotting
R/model.R                combined mcSimulation model
R/summarize.R            summary and certainty
R/bubble_plot.R          bubble matrix
R/pareto.R               welfare index, Pareto dominance, heatmap and frontier plot
R/exchange_rates.R       each group's own USD-equivalent prices for non-money values (within-group NPV)
R/game.R                 Stage 2: players, actions, Nash and sequential equilibria
R/compare.R              compares the two liability scenarios
R/plots_report.R         map, elevation and budget plots for the vignette and blog
bib/references.bib       references (checked against Crossref)
gis/                     OSM routes, Maine parcels, USGS elevation (see gis/README.md)
vignettes/, blog/        technical vignette and plain-language blog (Rmd)
docs/                    built HTML served by GitHub Pages (index.html = blog)
```

## Reports

```bash
Rscript run_all.R        # once, to write outputs/
Rscript build_docs.R     # knits the blog to docs/index.html and the vignette to docs/vignette.html
```

The reports read `outputs/` and `gis/outputs/`, so they do not rerun the Monte Carlo. To publish, turn on
GitHub Pages for this repository (Settings, Pages, deploy from branch `main`, folder `/docs`); the blog is then
at `https://cwwhitney.github.io/camden_carriage_road/`.

## Add or edit a stakeholder

Copy any file in `stakeholders/`, then change:
1. `dag_parents`: for each outcome value, the nodes that cause it (shared inputs, physical
   consequences from `R/helpers.R::phys_parents`, and this group's own inputs).
2. `inputs`: this group's own judgments, with 90% intervals. Prefix names uniquely.
3. `values`: name, label and unit of each outcome.
4. `outcomes(p, d)`: returns a named vector of discounted changes vs status quo, using the
   group's own discount rate.

`run_all.R` stops if the DAG, input table and outcome names disagree.

## Reading the bubble matrix

Blue = gain, red = loss (median vs status quo). Size = magnitude on that value's own scale
(rows are not comparable to each other). Transparency = certainty about the sign: solid means
nearly every run agrees.
