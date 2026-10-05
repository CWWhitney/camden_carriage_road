# Within-group NPV: each group's own "exchange rates" into USD-equivalent ---------------
# Stakeholder outcome functions already return DISCOUNTED values (each group uses its own
# discount rate). A group's NPV is the sum of its values times its own USD-equivalent price
# per unit:
#   * values already in USD count 1:1;
#   * non-money values (wellbeing points, stems, litters ...) get a placeholder shadow price,
#     which is uncertain and enters the Monte Carlo as an input (xr_<group>_<value>);
#   * values that would double count another value get 0 ("counted").
# Valuing non-money things in dollars is itself an ontological choice. A group may refuse it
# (the ecosystem group arguably should), which is why the unit-free welfare index stays too.
#
# WHERE THIS IS USED: only the within-group NPV Pareto views (outputs/*_npv.*). The bubble matrix,
# the unit-free welfare index and the game never use these prices.
#
# SOURCES FOR EVERY ECONOMIC TRANSFORMATION IN THIS STEP (references in bib/references.bib, all
# checked against Crossref on 2026-10-05; look here first when assessing the model):
#   * Discounting: each group keeps its own rate (landowners and business high; trees, climate and
#     future residents low). Basis for low long-run rates and for disagreement over them:
#     Arrow et al. 2013 (doi 10.1126/science.1235665); Drupp et al. 2018 (doi 10.1257/pol.20160240).
#   * Carbon (ecosystem:carbon_lost_tco2e): range taken from Rennert et al. 2022
#     (doi 10.1038/s41586-022-05224-9): mean 185 USD/tCO2, 5-95% range 44-413 USD (2020 USD).
#   * Wellbeing points (privacy, pride, noise, kids' mobility, cyclists, hikers, stress, youth):
#     method is the wellbeing-year (WELLBY) conversion of De Neve et al. 2020
#     (doi 10.1136/bmj.m3853). The method is cited; the 50-250 USD per point range is NOT from it
#     and stays a PLACEHOLDER until the points scale is tied to a wellbeing-year definition.
#   * Ecosystem items (stems, mature trees, soil, habitat, litters, roadkill, disturbance,
#     development pressure): practice of money-valuing ecosystem services is Costanza et al. 2014
#     (doi 10.1016/j.gloenvcha.2014.04.002); the per-unit ranges are PLACEHOLDERS, no number is taken.
#   * Brand points, conflict incidents: no source found yet; PLACEHOLDERS.
#   * Values already in USD (health benefit, injury cost, margins, payments) count 1:1 and involve
#     no transformation in this step.

xr_shadow <- list(   # USD-equivalent per unit: c(lower, upper). ALL PLACEHOLDERS.
  "landowners:privacy_wellbeing_pts"   = c(50, 250),
  "landowners:legacy_pride_pts"        = c(50, 250),
  "neighbors:noise_nuisance_pts"       = c(50, 250),
  "neighbors:kids_mobility_pts"        = c(50, 250),
  "ecosystem:stems_lost"               = c(20, 200),
  "ecosystem:mature_trees_lost"        = c(100, 1000),   # premium on top of the per-stem price
  "ecosystem:carbon_lost_tco2e"        = c(44, 413),     # CITED: Rennert et al. 2022, 5-95% range (2020 USD)
  "ecosystem:soil_sealed_ha"           = c(5000, 50000),
  "ecosystem:habitat_loss_ha"          = c(5000, 50000),
  "ecosystem:squirrel_litters_lost"    = c(10, 200),
  "ecosystem:roadkill_change"          = c(20, 200),
  "ecosystem:disturbance_events"       = c(0.5, 5),
  "cyclists:wellbeing_pts"             = c(50, 250),
  "hikers_walkers:access_gain_pts"     = c(50, 250),
  "hikers_walkers:solitude_loss_pts"   = c(50, 250),
  "hikers_walkers:conflict_incidents"  = c(100, 1000),
  "hikers_walkers:wild_character_loss_pts" = c(50, 250),
  "drivers_residents:near_miss_stress_pts" = c(50, 250),
  "town:snowbowl_brand_pts"            = c(100, 1000),
  "tourism_business:destination_brand_pts" = c(100, 1000),
  "climate_future:youth_mobility_pts"  = c(50, 250),
  "climate_future:development_pressure_ha" = c(5000, 50000)
)
xr_counted <- c("cyclists:injuries_avoided_count",   # valued through injury_cost_avoided_usd
                "tourism_business:jobs_fte",         # revenue already inside business_margin_usd
                "climate_future:net_tco2e_avoided")  # valued through climate_value_usd

xr_name <- function(stakeholder, value) paste0("xr_", stakeholder, "_", value)

xr_inputs <- function(stakeholders) {
  rows <- list()
  for (s in stakeholders) for (i in seq_len(nrow(s$values))) {
    key <- paste0(s$id, ":", s$values$value[i])
    if (s$values$unit[i] == "USD" || key %in% xr_counted) next
    rng <- xr_shadow[[key]]
    if (is.null(rng)) stop("No exchange rate for ", key)
    rows[[key]] <- E(xr_name(s$id, s$values$value[i]), rng[1], rng[2], "posnorm",
                     paste0("USD-equivalent per ", s$values$unit[i], ": ", s$values$label[i]),
                     if (key == "ecosystem:carbon_lost_tco2e")
                       "CITED range: Rennert et al. 2022 doi 10.1038/s41586-022-05224-9 (5-95%, 2020 USD)"
                     else "PLACEHOLDER shadow price (method sources in R/exchange_rates.R header): this group's own exchange rate into USD-equivalent")
  }
  do.call(rbind, rows)
}

# Within-group NPV per run: array [run, group, option], status_quo = 0 -----------------
welfare_npv <- function(mc, stakeholders) {
  y <- mc$y; x <- mc$x
  n <- nrow(y)
  opts <- c("status_quo", options_tbl$option)
  ids <- vapply(stakeholders, `[[`, "", "id")
  npv <- array(0, dim = c(n, length(ids), length(opts)), dimnames = list(NULL, ids, opts))
  for (s in stakeholders) for (o in options_tbl$option) {
    tot <- numeric(n)
    for (i in seq_len(nrow(s$values))) {
      v <- s$values$value[i]; key <- paste0(s$id, ":", v)
      price <- if (s$values$unit[i] == "USD") 1 else if (key %in% xr_counted) 0 else x[[xr_name(s$id, v)]]
      tot <- tot + y[[paste(s$id, v, o, sep = "__")]] * price
    }
    npv[, s$id, o] <- tot
  }
  npv
}
