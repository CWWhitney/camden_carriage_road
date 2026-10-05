# Game plan: one decision, many ontologies

## 1. The idea in one paragraph

A single real decision: **should a separated carriage-road bike path be
built between downtown Camden and the Camden Snow Bowl, instead of
relying on Hosmer Pond Road?** Every stakeholder group perceives that
same decision through its own *ontology*: what exists, what causes what,
and what counts as a good or bad outcome. We model each ontology as its
own causal diagram (DAG). Each DAG is turned into a small Monte Carlo
sub-model (inputs table plus an outcome function) using
`decisionSupport`. Running all the sub-models together gives, for every
stakeholder value and every option, a distribution of outcomes. We then
show them side by side in a Keeney-style consequence matrix drawn as a
bubble plot.

The point is not to find one "right" number. It is to make visible that
the same physical change (a few hectares of corridor, some trips, some
trees) means different things to different people, and to see where
interests align (for example, landowners who give up a little land and
also benefit) and where they collide.

## 2. Decision and options

Options are **parameter bundles** (see `options_tbl` in
`R/shared_decision.R`), so that in Stage 2 a player's action can simply
change one parameter.

| Option | What it is |
|----|----|
| `status_quo` | Hosmer Pond Road as it is. Implicit reference: every outcome is a change from here. |
| `shoulders` | Widen and improve on-road shoulders. |
| `shoulders_speed` | Shoulders plus a lower speed limit (safer, costs drivers time). |
| `carriage_path` | Separated carriage-road path on easements, some on private land (including parcels like those on Emery Way). Hosts get a one-off easement payment. |
| `path_compensated` | Path with double the one-off payment. |
| `path_annual` | Path with annual payments to hosts instead of a one-off payment. |
| `path_oneoff_annual` | Path with both a one-off and annual payments. |
| `path_donated` | Path on donated easements: no payment to hosts, who get a tax benefit and extra pride. No consideration is paid, so the liability exception cannot be triggered. |
| `path_cost_sharing` | Path under a binding cost-sharing agreement: local business must pay its host-payment share and a share of the Town's net capital and upkeep cost. |
| `path_mitigated` | Path with a narrower corridor and less clearing, at higher build cost. |
| `partial_path` | Path over 40% of the route only. |

All payments to hosts are funded by local business (its share) and the Town for the
remainder. The Snow Bowl is **not** a separate payer: it is a Town-owned special revenue fund (see
section 9), so what the Town pays is drawn from two pockets of one budget, the General Fund and the
Snow Bowl fund. Each payer values a payment stream at its own discount rate, which is what makes
one-off versus annual payments a real design choice: landowners discount heavily, so an annual stream
is worth less to them than a lump sum of the same nominal size.

## Staging

**Stage 1 (built): one policy-maker, many values.** "If one policy-maker
asked what each group gains or loses under each option, what would they
see?" Outputs: the Keeney bubble matrix, a welfare heatmap, a
Pareto-efficiency table and a frontier plot of one group against the
rest, each on the unit-free welfare index and on within-group NPV. Group
welfare is the equal-weight mean of that group's own scaled values (an
assumption, to be replaced with group-supplied weights). With the
placeholder inputs every option is Pareto-efficient, because each option
makes some group worse off. That is the point: no option is neutral, so
a recommendation implies a distributional choice.

**Stage 2 (built, v2): a community of agents who are also the decision-makers.** Three
players choose actions and the action profile maps to one of the Stage 1 configurations
(`R/game.R`). The Snow Bowl is inside the Town player, because the Town owns it (v1 had it as a fourth
player; see section 10):

| Player | Actions |
|----|----|
| Town of Camden (incl. the Snow Bowl) | nothing, shoulders, path |
| Landowners (one collective player) | refuse, one-off payment, annual payments, donate the easement |
| Local business | free-ride, contribute to host payments |

Rules: Town "nothing" gives the status quo; "shoulders" gives widened shoulders; "path" gives the
carriage path if landowners accept (payment form set by their action), or only the 40% on public land
with no host payments if they refuse. A free-rider's share of host payments falls on the Town. A
player's payoff is its own group welfare index from Stage 1. The Town also puts a weight on residents
(cyclists, neighbors, drivers, hikers), because elected officials answer to voters and the treasury.
That weight is a pure placeholder, so the run sweeps it.

Two mechanisms are compared. *Voluntary*: business chooses whether to contribute to host payments.
*Binding*: a cost-sharing agreement signed before construction (for example a special assessment); if
the Town builds a path, business must pay its host-payment share and a share of the Town's net capital
and upkeep cost (placeholder terms: 2-10%). Its action then no longer matters.

What it computes (all 24 action profiles, 1,500 Monte Carlo worlds, under each mechanism and each
liability scenario):
- the probability that each outcome is a pure Nash equilibrium (each Monte Carlo run is a possible
  world, and equilibria are found in every world);
- equilibria at mean payoffs, and whether they are Pareto-efficient among the three players;
- sequential (subgame-perfect) outcomes under all 6 orders of moves;
- the welfare of all 10 groups, bystanders included, under each outcome;
- sensitivity to the Town's weight on residents;
- a design sweep of the binding terms (`mechanism_grid`): for each business capital share and each
  level of outside grant money, and each landowner form, the share of worlds in which all three players
  are better off than under the status quo.

Limits of v2: pure equilibria only (no mixed strategies yet); landowners act as one player;
simultaneous-move and sequential versions are both shown but the real timing is itself a question; ties
are broken toward the most passive action; payoffs are group welfare indices with equal weights inside
each group; the Town and Snow Bowl share one discount rate.

## 3. Architecture

```         
shared physical layer  ->  10 stakeholder ontologies  ->  one MC model  ->  summary  ->  bubble matrix
(what changes on the     (each: DAG + input table +    (decisionSupport   (median, P(>0),   (size, color,
 ground; common ground)   outcome function)             mcSimulation)      certainty)        transparency)
```

- **Shared physical layer** (`R/shared_decision.R`): route length,
  costs, land taken, trees cleared, extra trips, injuries avoided and so
  on. Everyone agrees on these facts only as uncertain inputs; they do
  not agree on what they *mean*.
- **Stakeholder file** (`stakeholders/NN_name.R`): one DAG, its own
  input table (own parameters, own discount rate), a values table (name,
  label, unit) and an outcome function. Each file is self-contained.
- **Combined model** (`R/model.R`): loops over options and stakeholders
  and returns one named output per `stakeholder__value__option`.
- **Summary and plots** (`R/summarize.R`, `R/bubble_plot.R`,
  `R/pareto.R`) and the game layer (`R/game.R`).

## 4. Stakeholder ontologies (v2: 10)

| \# | Group | Sees the road as | Example values (unit) |
|----|----|----|----|
| 01 | Landowners hosting the path | Home, legacy and asset | net financial (USD), privacy (wellbeing pts), legacy pride (pts) |
| 02 | Neighbors not hosting | Quiet home environment | noise (pts), trespass cost (USD), kids' mobility (pts) |
| 03 | Forest managers / land trust | Working forest | stand value lost (USD), access savings (USD), management cost (USD) |
| 04 | Ecosystem (trees and wildlife) | Living forest systems | stems lost, carbon lost (tCO2e), habitat lost (ha), squirrel litters lost, roadkill change |
| 05 | Cyclists | Danger vs freedom | injuries avoided, health benefit (USD), wellbeing (pts) |
| 06 | Hikers and walkers | Quiet wild place | access gain (pts), solitude loss (pts), conflicts |
| 07 | Drivers and road residents | A route to share | delay saved (USD), near-miss stress (pts), speed-limit delay (USD) |
| 08 | Town of Camden (incl. the Snow Bowl) | One budget, two pockets: General Fund and a Town-owned Snow Bowl fund | net public cost (USD), tax gain (USD), EMS savings (USD), Snow Bowl margin (USD), liability (USD) |
| 09 | Tourism and local business | Visitor flow | business margin (USD), jobs (FTE), brand (pts) |
| 10 | Climate and future residents | Long-run commitments | net tCO2e, social cost (USD), youth mobility (pts) |

Trees and wildlife were separate stakeholders in the first draft and are
merged into one ecosystem voice for now, and the Snow Bowl and the Town are merged because the Town
owns the Snow Bowl (the earlier files are kept in `stakeholders_archive/`). They can be split again if the groups' values
turn out to pull apart.

Design rules for a good ontology file: 1. Own values, own units, own
discount rate (landowners and businesses discount heavily; trees,
climate and future residents barely at all). 2. Own inputs for
everything that is a judgment of that group (prices, sensitivities,
weights); only physical facts come from the shared layer. 3. Every input
and every outcome appears in the DAG, and the DAG has no orphan nodes.
`run_all.R` checks this automatically. 4. Outcomes are changes versus
`status_quo`, discounted over the horizon.

## 5. Reading the bubble matrix

- **Rows:** values, clustered by stakeholder group. **Columns:**
  options.
- **Color:** blue = median outcome is a gain, red = a loss.
- **Size:** the median's magnitude relative to that value's own scale
  (each value has its own unit, so sizes are only comparable within a
  row).
- **Transparency:** certainty. Solid means almost all simulation runs
  agree on the sign of the outcome; faint means the sign is close to a
  coin flip. Certainty = \|2 \* max(P(\>0), P(\<0)) - 1\|, rescaled to
  an alpha of 0.25-1.

## 6. Honest status of the numbers

All ranges in the input tables are **placeholders** I invented to make
the pipeline run, and every table row says so. None is an elicited or
measured value. No literature references are included, because none have
been verified against Crossref in this project. Replacing placeholders
with real numbers is the main job after the scaffold works (see phase
3).

## 7. Phases

| Phase | Goal | Done when |
|----|----|----|
| 0\. Scaffold (done) | Pipeline runs end to end with placeholder inputs, 6 options, Pareto view | `Rscript run_all.R` writes the CSVs, DAG pngs, bubble matrix and welfare/Pareto outputs with no validation errors |
| 1\. Review ontologies (done, 2026-10-04) | Cory checked the DAGs: right nodes, right arrows, right values | DAGs approved; trees and wildlife merged into ecosystem |
| 2\. Missing voices | Add groups (for example Camden Hills State Park, fire and EMS, school, abutting commercial, cyclists by type) and split groups that are not homogeneous | Stakeholder list agreed |
| 3\. Real inputs | Replace placeholders: GIS route length and parcel counts, cost per km quotes, crash records, counter data, easement valuation, group interviews and calibrated 90% intervals | Every row has a source note or an elicitation record |
| 4\. Analysis | Add `status_quo` comparison views, EVPI (which uncertain input matters most), and sensitivity of matrix signs | Report of "where would more information change the decision?" |
| 4b. Agents (Stage 2, v2 done) | Game layer: three players (Town incl. Snow Bowl, landowners, business), payoffs from the MC model; Nash equilibria vs the Pareto set; binding cost-sharing and grants | Equilibria computed and compared with Stage 1 (done). Next: mixed strategies, more players (grant agency, advocates), bond as a mechanism |
| 5\. Engagement | Use the matrix and DAGs in a talk or workshop, and let each group redraw its own DAG | Revised DAGs reflect the groups' own words |

## 8. Decisions so far (Cory)

1.  **Options:** the option set is good as it stands. Both payment
    structures (one-off and annual) are included as options so they can
    be tested against each other.
2.  **Landowner payment:** test one-off, annual, and both. Done in the
    model (`path_annual`, `path_oneoff_annual`).
3.  **Ecosystem:** one ecosystem voice for now; trees and wildlife are
    merged.
4.  **No combined score across stakeholders:** keep stakeholders
    separate. The only aggregation is within a group (the equal-weight
    welfare index of a group's own values), and the plan is to replace
    that with group-supplied weights.

## 9. Notes from Cory (2026-10-05) and how they were handled

**The Snow Bowl is the Town.** The Town of Camden owns the Snow Bowl and the Parks and Recreation
Department runs it ([Snow Bowl about page](https://camdensnowbowl.com/about-the-snow-bowl/)). The
Town's FY2026 municipal budget message lists the Snow Bowl among "the Town's special revenue funds"
(with Wastewater, Opera House and Paid Parking), separate from the General Fund, and says it "remains
difficult for the Snow Bowl to turn a profit while also keeping season pass and ticket prices low",
floating an operating subsidy from the Town ([FY2026 budget PDF](https://cms8.revize.com/revize/camdenmaine/FY%202026%20Municipal%20Budget%20janice%20copy.pdf);
read directly this session). Pen Bay Pilot coverage describes the fund as an enterprise fund outside
the Budget Committee's general-fund review (search snippet only, not read in full). So the model now
has **one Town ontology with two budget pockets**:

- the **General Fund** (taxes) pays most of the path's capital and upkeep, winter maintenance and the
  Town's share of landowner payments;
- the **Snow Bowl fund** earns the added margin from more visitors (with the growth of mountain
  biking and bikepacking as the upside case) and carries the extra liability and staff effects.

A clear and logical solution is an **earmark**: the Snow Bowl fund's added margin is dedicated to the
path's cost, and the General Fund covers the rest plus whatever grants and business do not. On
the placeholder run the added Snow Bowl margin is a median of about 342k USD (present value), against
about 1.18M USD of net capital and upkeep for the Town and about 73k USD of landowner payments (one-off
case). So an earmark alone covers roughly a quarter to a third of the Town's cost, and grants
and cost sharing matter. Not verified: the Snow Bowl's own line items and reserves (not found in the
budget message; the Snow Bowl fund budget is a separate document). The old split parameters
(`comp_share_snowbowl`, `mech_capshare_snowbowl`) are removed; the earlier files are in
`stakeholders_archive/`.

**Pareto on within-group discounted NPV.** A second view next to the welfare index
(`R/exchange_rates.R`, `outputs/*_npv.*`). Each group's values are already discounted at its own rate;
a group's NPV is the sum of its values times its own USD-equivalent price. Money values count 1:1,
non-money values get a shadow price that enters the Monte Carlo, and values that would double count
another get zero. **This conversion is used only in the NPV Pareto figures** (not in the bubble matrix,
the welfare index or the game). Sources for every economic transformation in this step are now in the
header of `R/exchange_rates.R` and in `bib/references.bib`, all checked against Crossref on 2026-10-05:
- carbon: the range 44-413 USD per tCO2 is taken from Rennert et al. 2022
  (doi 10.1038/s41586-022-05224-9), whose Crossref abstract gives a mean of 185 USD and a 5-95% range
  of 44-413 USD (2020 USD);
- wellbeing points: the method (wellbeing-year conversion) is De Neve et al. 2020
  (doi 10.1136/bmj.m3853); the USD per point stays a placeholder because no number was taken from it;
- ecosystem items: the practice of valuing ecosystem services in money is Costanza et al. 2014
  (doi 10.1016/j.gloenvcha.2014.04.002); per-unit numbers are placeholders;
- discounting by group: Arrow et al. 2013 (doi 10.1126/science.1235665) and Drupp et al. 2018
  (doi 10.1257/pol.20160240);
- brand points and conflict incidents: no source found, placeholders.
Two things to know: valuing non-money things in dollars is itself an ontological choice (the ecosystem
group may refuse it, which is why the unit-free index stays), and the two views can disagree on sign for
some groups, so conclusions are sensitive to the exchange rates. That is a finding about what must be
elicited, not a bug.

**Standards and laws about payment (research, 2026-10-05; not legal advice, needs a Maine attorney or
appraiser).** The values in the model follow these sources, and the same notes now sit in the code
header of `physical_delta` (`R/shared_decision.R`) so they are easy to find when assessing the model:
- Maine's constitution requires just compensation when private property is taken for public use. For a
  partial taking the measure is generally the fair market value before minus after (a "before and
  after" appraisal) ([Maine Law Review article on partial
  takings](https://digitalcommons.mainelaw.maine.edu/mlr/vol27/iss2/5/), seen only as a search
  result, not read in full). Eminent domain is the legal backstop, not the plan; the appraisal is the
  natural benchmark for a fair one-off payment (`easement_payment_per_ha`).
- [14 MRSA section 159-A](https://legislature.maine.gov/statutes/14/title14sec159-A.html) limits the
  duty of care of owners toward people using land for recreation and lists biking. It does not cover
  willful or malicious failure to warn, and does not apply where permission is granted for a
  consideration. Whether paying for an easement triggers that exception drives the two liability
  scenarios (`liability_exposed_mult`, a placeholder 3x-15x).
- I did not find Maine or Camden-specific standard rates for path easements.

## 10. Decisions on the two open questions (Cory, 2026-10-05, revised)

1. **The Snow Bowl is part of the Town, not a separate player.** Version 1 kept it separate as a
   semi-independent budget; Cory's note and the Town budget document (section 9) show it is a
   Town-owned fund, so it is now inside the Town player and ontology. The game has three players.
2. **Liability: run both legal cases as scenarios** (built in `physical_delta`, `R/compare.R`):
   - *protected*: hosts keep the Maine recreational-use protection and pay base liability costs;
   - *exposed*: paid permission counts as consideration, the protection may not apply, and host
     liability cost is multiplied (placeholder range 3x to 15x, `liability_exposed_mult`). Every analysis
     is written once per scenario in `outputs/liability_protected/` and `outputs/liability_exposed/`,
     plus `outputs/liability_comparison.*`.

What the placeholder run shows about liability: in the protected scenario most paid path options leave
landowners better off at the median (one-off payment: about +46k USD); in the exposed scenario every
paid option leaves them worse off (one-off: about -139k USD), and a donated easement (about -17k USD in
both) is unaffected. The liability multiple only applies to payments, so shoulders are unaffected. Not
modeled: the Town's own liability as easement holder (a candidate new option).

## 11. What the placeholder game shows now (shape only, not evidence)

- **Putting the Snow Bowl inside the Town changes the story.** In v1 the Town's own payoff was the
  bottleneck and the status quo was the most likely stable outcome (path stable in roughly 30% of worlds).
  With the Snow Bowl's added margin counted in the Town's payoff, a path equilibrium exists in about 62%
  (voluntary) to 63% (binding) of worlds at a Town weight of 0.5 in the protected scenario, and the status
  quo is stable in about 45-46%. Both can be stable at once, which is a coordination problem. The earlier
  "the Town blocks it" result came from leaving the Snow Bowl's gains out of the Town's payoff.
- **The donated easement is the most promising landowner form**, mainly because nobody has to pay
  landowners, but it rests on two placeholder assumptions (donation tax benefit, extra pride) that are
  the first things to check. Landowners' median net financial position is about -17k USD and they gain
  only through the tax benefit and pride. Tax treatment of easement donations needs a tax advisor.
- **Binding cost-sharing moves the result very little** (path-stable share rises from about 62% to 63%).
- **Grants matter more than asking business for more.** In the design sweep, the share of worlds where
  all three players gain is highest with no business share and 80% outside grants (about 54% for a donated
  easement in the protected scenario) and falls as business is asked to pay more, down to 2-3% at a 30%
  business share with 20% grants.

Limits: the mechanism covers the path only (not shoulders); binding shares are fixed per world, not
negotiated; the Town's weight on residents remains a placeholder.

## 12. Open questions

1. Grants and a bond as mechanisms: grants are swept in `mechanism_grid`; a bond is not yet modeled
   (the Snow Bowl redevelopment used one).
2. How should donated-easement assumptions (tax benefit, pride) be bounded: tax advisor, land trust,
   or landowner interviews?
3. The Snow Bowl fund's own books: how much of the added margin can really be earmarked, given the
   fund runs near break even? (Resolved: it shares one budget with the Town in the game.)
4. Should the discount rate differ between the General Fund and the Snow Bowl fund? One Town rate is
   used for now.

## 13. GIS workflow: maps of candidate routes (started 2026-10-05)

Goal: compare route concepts on maps and use them to replace placeholder geography in the model (route
length, land taken, clearing, host parcels). Code and notes are in `gis/`.

First run, on OpenStreetMap data (approximate, see `gis/README.md`): one dominant corridor connects
downtown Camden and the Snow Bowl's road access, Mechanic Street to Hosmer Pond Road to Barnestown Road,
at 6.91 km against a 5.98 km straight line. The best route avoiding Hosmer Pond Road is 7.87 km (about
14% longer).

Parcels and elevation (Cory approved the downloads; `gis/03_parcels_elevation.R`; Maine GeoLibrary
parcels within 150 m of the routes, USGS 3DEP elevation every 50 m; private owner names were not
downloaded): a path beside the main corridor touches about 206 tax parcels, 197 privately owned and 9
public or conservation. The climb from downtown (about 11 m) to the road base (about 137 m) is about
127 m. Parcel data are submitted by towns on an unscheduled basis and can be old.

Next: missing-link analysis for trail-based routes; feed measured route length, parcel counts and
private share into `R/shared_decision.R` in place of the placeholders and add the route alternatives as
options so Stage 1 and the game see the geography.

## 14. Reports and hosting

`vignettes/camden_carriage_road.Rmd` is the technical vignette and `blog/index.Rmd` the plain-language
blog for the Town of Camden. Both read the files in `outputs/` and `gis/` (no Monte Carlo rerun) and
knit with `Rscript build_docs.R`, which writes `docs/index.html` (blog) and `docs/vignette.html`. The
`docs/` folder is what GitHub Pages serves.
