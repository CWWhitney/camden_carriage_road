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
`R/shared_decision.R`), not just names, so that in Stage 2 a player's
action can simply change one parameter.

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
| `path_cost_sharing` | Path under a binding cost-sharing agreement: the Snow Bowl and business must pay their host-payment shares and a share of the Town's net capital and upkeep cost. |
| `path_mitigated` | Path with a narrower corridor and less clearing, at higher build cost. |
| `partial_path` | Path over 40% of the route only. |

All payments to hosts are funded by a beneficiary pool (Snow Bowl, local
business, and the Town for the remainder). Each payer values a payment
stream at its own discount rate, which is what makes one-off versus
annual payments a real design choice: landowners discount heavily, so an
annual stream is worth less to them than a lump sum of the same nominal
size.

## Staging

**Stage 1 (built): one policy-maker, many values.** "If one policy-maker
asked what each group gains or loses under each option, what would they
see?" Outputs: the Keeney bubble matrix, a welfare heatmap, a
Pareto-efficiency table and a frontier plot of one group against the
rest, each on the unit-free welfare index and on within-group NPV. Group welfare is the equal-weight mean of that group's own scaled
values (an assumption, to be replaced with group-supplied weights). With
the placeholder inputs every option is Pareto-efficient, because each
option makes some group worse off. That is the point: no option is
neutral, so a recommendation implies a distributional choice.

**Stage 2 (built, v1): a community of agents who are also the
decision-makers.** Four players choose actions and the action profile
maps to one of the Stage 1 configurations (`R/game.R`):

| Player | Actions |
|----|----|
| Town of Camden | nothing, shoulders, path |
| Landowners (one collective player) | refuse, one-off payment, annual payments, donate the easement |
| Snow Bowl | free-ride, contribute to host payments |
| Local business | free-ride, contribute to host payments |

Rules: Town "nothing" gives the status quo; "shoulders" gives widened
shoulders; "path" gives the carriage path if landowners accept (payment
form set by their action), or only the 40% on public land with no host
payments if they refuse. A free-rider's share of host payments falls on
the Town. A player's payoff is its own group welfare index from Stage 1.
The Town also puts a weight on residents (cyclists, neighbors, drivers,
hikers), because elected officials answer to voters and not only to the
treasury. That weight is a pure placeholder, so the run sweeps it.

Two mechanisms are compared. *Voluntary*: the Snow Bowl and business choose whether to contribute
to host payments. *Binding*: a cost-sharing agreement signed before construction; if the Town builds
a path, they must pay their host-payment shares and a share of the Town's net capital and upkeep
cost (placeholder terms: Snow Bowl 5-25%, business 2-10%). Their actions then no longer matter.

What it computes (all 48 action profiles, 1,500 Monte Carlo worlds, under each mechanism):
- the probability that each outcome is a pure Nash equilibrium (each Monte Carlo run is a possible
  world, and equilibria are found in every world);
- equilibria at mean payoffs, and whether they are Pareto-efficient among the four players;
- sequential (subgame-perfect) outcomes under all 24 orders of moves;
- the welfare of all 11 groups, bystanders included, under each outcome;
- sensitivity of all this to the Town's weight on residents;
- a design sweep of the binding terms (`mechanism_design_grid`): for each pair of Snow Bowl and
  business capital shares and each landowner form, the share of worlds in which all four players
  are better off than under the status quo.

What the placeholder run shows (shape only, not evidence): the status
quo is the most likely stable outcome. The Snow Bowl and business gain
from a path whether or not they pay for it, so voluntary contributions
fail (the free-rider problem), and the Town's treasury view makes a path
a net cost. A path appears only if the Town weights residents very
heavily. That points to mechanisms (a binding cost-sharing agreement, a
special district, grants) as the next thing to model, not just more
precise numbers.

Limits of v1: pure equilibria only (no mixed strategies yet); landowners
act as one player; simultaneous-move and sequential versions are both
shown but the real timing is itself a question; ties are broken toward
the most passive action; payoffs are group welfare indices with equal
weights inside each group.

## 3. Architecture

```         
shared physical layer  ->  11 stakeholder ontologies  ->  one MC model  ->  summary  ->  bubble matrix
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

## 4. Stakeholder ontologies (v1: 11)

| \# | Group | Sees the road as | Example values (unit) |
|----|----|----|----|
| 01 | Landowners hosting the path | Home, legacy and asset | net financial (USD), privacy (wellbeing pts), legacy pride (pts) |
| 02 | Neighbors not hosting | Quiet home environment | noise (pts), trespass cost (USD), kids' mobility (pts) |
| 03 | Forest managers / land trust | Working forest | stand value lost (USD), access savings (USD), management cost (USD) |
| 04 | Ecosystem (trees and wildlife) | Living forest systems | stems lost, carbon lost (tCO2e), habitat lost (ha), squirrel litters lost, roadkill change |
| 05 | Cyclists | Danger vs freedom | injuries avoided, health benefit (USD), wellbeing (pts) |
| 06 | Hikers and walkers | Quiet wild place | access gain (pts), solitude loss (pts), conflicts |
| 07 | Drivers and road residents | A route to share | delay saved (USD), near-miss stress (pts), speed-limit delay (USD) |
| 08 | Camden Snow Bowl | A destination to fill | operating margin (USD), staff commute (USD), liability (USD) |
| 09 | Town of Camden | Budget line and tax base | net public cost (USD), tax gain (USD), EMS savings (USD) |
| 10 | Tourism and local business | Visitor flow | business margin (USD), jobs (FTE), brand (pts) |
| 11 | Climate and future residents | Long-run commitments | net tCO2e, social cost (USD), youth mobility (pts) |

Trees and wildlife were separate stakeholders in the first draft and are
merged into one ecosystem voice for now (the earlier files are kept in
`stakeholders_archive/`). They can be split again if the groups' values
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
| 4b. Agents (Stage 2, v1 done) | Game layer: players, actions, payoffs from the MC model; Nash equilibria vs the Pareto set | Equilibria computed and compared with Stage 1 (done). Next: mixed strategies, mechanisms (binding cost-sharing), more players (grant agency, advocates) |
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

## 9. Notes from Cory, and what was done with them

**Payment split between the Town and the Snow Bowl.** Adopted as the working assumption: the
Snow Bowl pays 30-60% of host payments, local business 1-10%, and the Town the rest. All
placeholders. Caveat below: the Snow Bowl is town-owned.

**Pareto on within-group discounted NPV.** Built as a second view next to the welfare index
(`R/exchange_rates.R`, `outputs/*_npv.*`). Each group's values are already discounted at its own
rate; a group's NPV is the sum of its values times its own exchange rates into USD-equivalent.
Money values count 1:1, non-money values (wellbeing points, stems, litters) get a placeholder
shadow price that is uncertain and enters the Monte Carlo, and values that would double count
another value get zero. Two things to know:
- Valuing non-money things in dollars is itself an ontological choice. The ecosystem group may
  refuse to do it, which is why the unit-free index stays alongside.
- The two views can disagree on sign for some groups (for example neighbors, and landowners under
  annual payments), so conclusions are sensitive to the exchange rates. That is a finding about
  what must be elicited, not a bug.

**Are there existing standards and laws about payment? (research, 2026-10-05).** Short answer: yes,
and they matter for the model, but this is not legal advice and needs a Maine attorney or
appraiser.
- Maine's constitution requires just compensation when private property is taken for public use.
  For a partial taking the measure is generally the fair market value of the property before
  minus after the taking (a "before and after" appraisal). Source: a
  [Maine Law Review article on partial takings](https://digitalcommons.mainelaw.maine.edu/mlr/vol27/iss2/5/),
  seen only as a search result, not read in full. Eminent domain is the legal backstop, not the
  plan: a voluntary easement is negotiated, but the before-and-after appraisal is the natural
  benchmark for what a fair one-off payment looks like.
- Maine's recreational use statute,
  [14 MRSA section 159-A](https://legislature.maine.gov/statutes/14/title14sec159-A.html), limits the
  duty of care of owners and easement holders toward people using land for recreation, and lists
  biking. The protection does not cover willful or malicious failure to warn, and it does not apply
  where permission was granted for a consideration (beyond nominal fees or certain state payments).
  Whether paying landowners for a path easement triggers that exception is a real question for a
  lawyer, and it could change the liability cost in landowner payoffs and the choice between
  one-off and annual payments.
- I did not find, and did not look for, Maine or Camden-specific standard rates for path
  easements. Easement valuation by appraisal is the likely route.

**The Snow Bowl is town-owned.** The Town of Camden owns it and the Parks and Recreation Department
runs it ([Snow Bowl about page](https://camdensnowbowl.com/about-the-snow-bowl/)). Two
foundations and clubs support it. So "Town versus Snow Bowl" is a split inside one municipality
(general fund versus Snow Bowl revenue or foundation money), not two independent payers. I have not
verified whether the Snow Bowl has its own budget line.

## 10. Decisions on the two open questions (Cory, 2026-10-05)

1. **Snow Bowl stays a separate player** in the game, even though the Town owns it. It is treated
   as a semi-independent budget with its own foundation and supporters.
2. **Liability: run both legal cases as scenarios** (built in `physical_delta`, `R/compare.R`):
   - *protected*: hosts keep the Maine recreational-use protection and pay base liability costs.
   - *exposed*: paid permission counts as consideration, the protection may not apply, and host
     liability cost is multiplied (placeholder range 3x to 15x, `liability_exposed_mult`).
   Every analysis (bubble matrix, Pareto views, game) is now written once per scenario in
   `outputs/liability_protected/` and `outputs/liability_exposed/`, plus
   `outputs/liability_comparison.*`.

What the placeholder run shows: the liability question changes the landowners' case a lot. In the
protected scenario most path options leave landowners slightly better off at the median; in the
exposed scenario every path option leaves them worse off, and in more worlds they refuse to host
(a partial path on public land becomes stable in about 6% of worlds versus almost none). It does
not change the headline of the game: with these placeholders the status quo stays the most
likely stable outcome in both, because the Town's own payoff, not the landowners', is what blocks
a path. The liability multiple only applies to payments, so shoulders are unaffected. Not modeled:
a donated easement with no payment (which may avoid the consideration exception) and the Town's
own liability as easement holder. Both are candidates for new options.

## 11. Donated easement and binding cost-sharing (built 2026-10-05)

Both were added at Cory's request. What the placeholder run shows (shape only, not evidence):
- **Binding cost-sharing barely moves the result.** With binding terms, the share of worlds in which
  some equilibrium builds a path rises by roughly 5 percentage points (for example 27% to 33% at a
  Town weight of 0.5), and the status quo remains stable in about 70% of worlds. Status quo and path
  equilibria coexist in many worlds, so this is a coordination problem as well as a free-rider one.
- **Shifting more cost onto the Snow Bowl and business does not help.** In the design sweep, the
  share of worlds where all four players gain is highest when the Snow Bowl and business pay
  nothing toward capital (about 17% for one-off or annual payments, about 32% for a donated
  easement) and falls as their shares rise. The Town's own payoff stays near zero on average, so it
  is the Town, not the free-riders, that most often blocks agreement.
- **The donated easement is the most promising landowner form** in these runs, in both liability
  scenarios, mainly because nobody has to pay landowners. But it rests on two placeholder
  assumptions (donation tax benefit, extra pride from donating) that are the first things to check:
  landowners' median net financial position is negative (about -16k USD) and they gain only through
  the tax benefit and pride. Tax treatment of easement donations needs a tax advisor; nothing here
  is tax advice.
- The path outcomes counted as "path stable" include the partial path when landowners refuse.

Limits: the mechanism covers the path only (not shoulders); binding shares are fixed per world, not
negotiated; the Town's weight on residents remains a placeholder that drives much of the result.

## 12. Open questions

1. Is the Town's payoff the real bottleneck? A Town that weights residents more, or outside money
   (grants, state funds, a bond) that changes the Town's cost share, might do more than moving cost
   between the Town and its beneficiaries. Model grants and a bond as mechanisms?
2. How should donated-easement assumptions (tax benefit, pride) be bounded: tax advisor, land
   trust, or landowner interviews?
3. Should the Town and the Snow Bowl share one budget in the game (they are one municipality), as a
   robustness check on keeping the Snow Bowl separate?
