# Shared physical layer ---------------------------------------------------------
# What changes on the ground under each option, relative to status quo.
# ALL RANGES ARE PLACEHOLDERS (90% intervals, to be replaced with GIS
# measurements, quotes, crash records and counter data).

# Options are parameter bundles, not just names. In a later "agents" stage a
# player's action simply changes one of these parameters.
#   type        "shoulders" (on-road) or "path" (separated carriage road)
#   route_frac  share of the route a path covers
#   width_scale / clear_scale   corridor width and clearing relative to the standard path
#   mitigated   1 = costlier build that narrows the footprint (mitigation_cost_mult)
#   oneoff_mult multiple of the base one-off easement payment to hosts (0 = none)
#   annual_mult multiple of the base annual payment to hosts (0 = none)
#   donated     1 = hosts donate the easement (no payment; they get a tax benefit and extra pride)
#   binding     1 = binding cost-sharing agreement: local business must pay its share of host
#               payments AND a share of the Town's net capital and upkeep cost of the path
#   All payments to hosts are funded by local business (its share) and the Town. The Snow Bowl is
#   a Town-owned special revenue fund, not a separate payer: see stakeholders/08_town.R.
#   speed_limit 1 = lower speed limit on the road
# status_quo is implicit: every outcome is a change from it.
options_tbl <- data.frame(
  option      = c("shoulders", "shoulders_speed", "carriage_path", "path_compensated",
                  "path_annual", "path_oneoff_annual", "path_donated", "path_cost_sharing",
                  "path_mitigated", "partial_path"),
  label       = c("Widened shoulders", "Shoulders + lower speed limit",
                  "Separated carriage path (one-off easement)",
                  "Path + doubled one-off payment",
                  "Path + annual payments (no one-off)",
                  "Path + one-off and annual payments",
                  "Path + donated easement (no payment)",
                  "Path + binding cost-sharing agreement",
                  "Path + footprint mitigation", "Partial path (40% of route)"),
  type        = c("shoulders", "shoulders", rep("path", 8)),
  route_frac  = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 0.4),
  width_scale = c(1, 1, 1, 1, 1, 1, 1, 1, 0.7, 1),
  clear_scale = c(1, 1, 1, 1, 1, 1, 1, 1, 0.6, 1),
  mitigated   = c(0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
  oneoff_mult = c(1, 1, 1, 2, 0, 1, 0, 1, 1, 1),
  annual_mult = c(0, 0, 0, 0, 1, 1, 0, 0, 0, 0),
  donated     = c(0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
  binding     = c(0, 0, 0, 0, 0, 0, 0, 1, 0, 0),
  speed_limit = c(0, 1, 0, 0, 0, 0, 0, 0, 0, 0),
  stringsAsFactors = FALSE
)

shared_inputs <- rbind(
  E("route_km", 5, 9, "posnorm", "Route length, downtown Camden to Snow Bowl (km)"),
  E("horizon_yrs", 20, 40, "posnorm", "Evaluation horizon (years)"),
  E("path_cost_per_km", 3e5, 1.2e6, "posnorm", "Capital cost, separated path (USD/km)"),
  E("shoulder_cost_per_km", 1e5, 4e5, "posnorm", "Capital cost, widened shoulders (USD/km)"),
  E("grant_share", 0.3, 0.8, "tnorm_0_1", "Share of capital cost met by outside grants"),
  E("path_maint_per_km_yr", 3000, 12000, "posnorm", "Maintenance, path (USD/km/yr)"),
  E("shoulder_maint_per_km_yr", 1000, 4000, "posnorm", "Maintenance, shoulders (USD/km/yr)"),
  E("corridor_width_m", 6, 14, "posnorm", "Path corridor width incl. buffer (m)"),
  E("shoulder_extra_width_m", 2.4, 5, "posnorm", "Extra road width for shoulders, both sides (m)"),
  E("path_private_share", 0.5, 0.9, "tnorm_0_1", "Share of path corridor on private land"),
  E("shoulder_private_land_share", 0.05, 0.4, "tnorm_0_1", "Share of shoulder widening on private land"),
  E("clearing_fraction", 0.2, 0.6, "tnorm_0_1", "Share of path corridor that is forest needing clearing"),
  E("shoulder_clear_fraction", 0.15, 0.5, "tnorm_0_1", "Share of shoulder widening needing clearing"),
  E("edge_depth_m", 20, 50, "posnorm", "Depth of degraded edge on each side of a clearing (m)"),
  E("baseline_bike_trips_yr", 3000, 15000, "posnorm", "Full-route bike trips per year today"),
  E("baseline_walk_trips_yr", 2000, 8000, "posnorm", "Walk/hike trips along the corridor per year today"),
  E("baseline_car_trips_yr", 2e5, 6e5, "posnorm", "Car trips per year on the route today"),
  E("demand_mult_path", 1.5, 4, "posnorm", "Bike trips after path, multiple of today"),
  E("demand_mult_shoulders", 1.1, 1.6, "posnorm", "Bike trips after shoulders, multiple of today"),
  E("road_share_path", 0.1, 0.4, "tnorm_0_1", "Share of bike trips still on the road after path"),
  E("baseline_injuries_per_10k_trips", 0.3, 2.5, "posnorm", "Injury crashes per 10,000 bike trips today"),
  E("risk_mult_path", 0.1, 0.4, "tnorm_0_1", "Remaining injury risk per trip with path"),
  E("risk_mult_shoulders", 0.5, 0.85, "tnorm_0_1", "Remaining injury risk per trip with shoulders"),
  E("walk_mult_path", 1.2, 3, "posnorm", "Walk trips after path, multiple of today"),
  E("walk_mult_shoulders", 1.0, 1.2, "posnorm", "Walk trips after shoulders, multiple of today"),
  E("car_replace_share", 0.2, 0.5, "tnorm_0_1", "Share of new bike trips that replace a car trip"),
  E("easement_payment_per_ha", 5000, 30000, "posnorm", "Base one-off easement payment to hosts (USD/ha)"),
  E("annual_payment_per_ha", 200, 1200, "posnorm", "Base annual payment to hosts (USD/ha/yr)"),
  E("donation_tax_benefit_share", 0.05, 0.35, "posnorm", "Tax benefit of donating an easement, as a share of the value of the land given (placeholder; needs a tax advisor)"),
  E("town_cost_share", 0.2, 0.6, "tnorm_0_1", "Town share of the non-grant capital and upkeep cost of the path"),
  E("mech_capshare_business", 0.02, 0.1, "tnorm_0_1", "Binding agreement: share of the Town's net capital and upkeep cost paid by local business"),
  E("liability_exposed_mult", 3, 15, "posnorm", "Multiple on host liability cost if payments void the recreational-use protection (used only in the exposed scenario)"),
  E("mitigation_cost_mult", 1.1, 1.5, "posnorm", "Capital cost multiple for the mitigated design"),
  E("comp_share_business", 0.01, 0.1, "tnorm_0_1", "Share of host payments paid by local business (the Town pays the rest, from the General Fund and/or Snow Bowl fund)"),
  E("speed_risk_mult", 0.75, 0.95, "tnorm_0_1", "Injury risk multiple from a lower speed limit"),
  E("speed_delay_min_per_car_trip", 0.5, 2, "posnorm", "Extra minutes per car trip from the lower speed limit")
)

# Change versus status quo for one option. p = named list of all inputs.
# Stage 2 (game) switches, all default 1 so Stage 1 is unchanged:
#   tb_pays            whether local business pays its share of host payments
#                      (if not, the Town covers that share)
#   binding            1 = apply the binding cost-sharing agreement whatever the option
#   hosts              0 = landowners refuse: no private land taken, no host payments
#   liability          "protected": hosts keep Maine recreational-use protection (14 MRSA 159-A),
#                      so base liability cost applies. "exposed": paid permission counts as
#                      "consideration" and voids it, so host liability cost is multiplied.
#                      Legal status is unresolved, so both are run as scenarios.
# SOURCES FOR THE LEGAL ASSUMPTIONS (research 2026-10-05; not legal advice, needs a Maine attorney):
#   * 14 MRSA section 159-A (recreational use; lists biking; no protection for willful or malicious
#     failure to warn; not where permission is granted for a consideration):
#     https://legislature.maine.gov/statutes/14/title14sec159-A.html
#   * Just compensation for a partial taking = before-and-after fair market value (benchmark for the
#     one-off easement payment, easement_payment_per_ha). Maine Law Review article on partial
#     takings, seen only as a search result, not read in full:
#     https://digitalcommons.mainelaw.maine.edu/mlr/vol27/iss2/5/
#   * liability_exposed_mult (3x-15x) and the donation tax benefit are PLACEHOLDERS, not sourced.
physical_delta <- function(p, option, tb_pays = 1, hosts = 1,
                           liability = c("protected", "exposed"), binding = 0) {
  liability <- match.arg(liability)
  o <- options_tbl[options_tbl$option == option, ]
  stopifnot(nrow(o) == 1)
  with(p, {
    path <- o$type == "path"
    bind <- max(o$binding, binding) * as.numeric(path)
    f <- if (path) o$route_frac else 0              # path intensity (0 for shoulders)
    built_km <- route_km * (if (path) o$route_frac else 1)

    mult  <- if (path) 1 + (demand_mult_path - 1) * f else demand_mult_shoulders
    rmult <- if (path) 1 - f * (1 - risk_mult_path) else
               risk_mult_shoulders * (if (o$speed_limit == 1) speed_risk_mult else 1)
    road_share <- if (path) 1 - f * (1 - road_share_path) else 1
    walk_mult  <- if (path) 1 + (walk_mult_path - 1) * f else walk_mult_shoulders
    width_m <- if (path) corridor_width_m * o$width_scale else shoulder_extra_width_m
    clr     <- if (path) clearing_fraction * o$clear_scale else shoulder_clear_fraction
    unit_cost <- if (path) path_cost_per_km * (1 + o$mitigated * (mitigation_cost_mult - 1)) else
                   shoulder_cost_per_km
    corridor_ha <- built_km * 1000 * width_m / 1e4

    capital <- built_km * unit_cost
    land_ha <- hosts * corridor_ha * (if (path) path_private_share else shoulder_private_land_share)
    extra_bike <- baseline_bike_trips_yr * (mult - 1)
    car_avoided <- extra_bike * car_replace_share

    list(
      option_is_path         = f,
      host_share             = hosts * (if (path) f else 1),
      liability_mult         = if (liability == "exposed" && (o$oneoff_mult + o$annual_mult) > 0 && hosts == 1)
                                 liability_exposed_mult else 1,
      donated                = o$donated,
      capshare_business      = bind * mech_capshare_business,
      share_business         = comp_share_business * tb_pays,
      route_km               = route_km,
      capital_cost           = capital,
      public_capital_cost    = capital * (1 - grant_share),
      annual_maint           = built_km * (if (path) path_maint_per_km_yr else shoulder_maint_per_km_yr),
      land_ha                = land_ha,
      clear_ha               = corridor_ha * clr,
      edge_ha                = built_km * 1000 * 2 * edge_depth_m * clr / 1e4,
      payment_oneoff         = land_ha * easement_payment_per_ha * o$oneoff_mult,
      payment_annual         = land_ha * annual_payment_per_ha * o$annual_mult,
      extra_bike_trips       = extra_bike,
      road_bike_trips_change = baseline_bike_trips_yr * (mult * road_share - 1),
      injuries_avoided       = baseline_bike_trips_yr * baseline_injuries_per_10k_trips *
                                 (1 - mult * rmult) / 1e4,
      extra_walk_trips       = baseline_walk_trips_yr * (walk_mult - 1),
      car_trips_avoided      = car_avoided,
      car_km_avoided         = car_avoided * route_km,
      speed_delay_min        = o$speed_limit * speed_delay_min_per_car_trip,
      trail_km_new           = if (path) built_km else 0,
      shoulder_km            = if (path) 0 else route_km
    )
  })
}

# Midpoints of the shared table (used for validation and quick tests)
mid_inputs <- function(tbl) {
  setNames(as.list((tbl$lower + tbl$upper) / 2), tbl$variable)
}
