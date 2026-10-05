# Cyclists (commuters, recreational riders, families)
# Ontology: the road is a danger to be survived; a separated path is freedom,
# health and the end of fear of traffic.

stakeholder <- new_stakeholder(
  id = "cyclists",
  label = "Cyclists",
  ontology = "Road as danger; separation as safety, health and freedom to ride; moderate discounting.",
  dag_parents = list(
    injuries_avoided_count = c("injuries_avoided", "cy_discount_rate", "horizon_yrs"),
    injury_cost_avoided_usd = c("injuries_avoided", "cy_injury_cost_usd", "cy_discount_rate", "horizon_yrs"),
    health_benefit_usd = c("extra_bike_trips", "route_km", "cy_health_usd_per_km", "cy_discount_rate", "horizon_yrs"),
    wellbeing_pts = c("extra_bike_trips", "baseline_bike_trips_yr", "cy_wellbeing_pts_per_new_trip",
                      "cy_stress_relief_pts_per_trip", "option_is_path", "cy_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("cy_injury_cost_usd", 8000, 60000, "posnorm", "Cost of an injury crash to the rider (USD)"),
    E("cy_health_usd_per_km", 0.3, 1.2, "posnorm", "Physical-activity health benefit per km ridden (USD)"),
    E("cy_wellbeing_pts_per_new_trip", 0.05, 0.3, "posnorm", "Wellbeing per additional trip (pts)"),
    E("cy_stress_relief_pts_per_trip", 0.05, 0.4, "posnorm", "Wellbeing from reduced fear on each existing trip (pts)"),
    E("cy_discount_rate", 0.02, 0.06, "tnorm_0_1", "Discount rate (cyclists)")
  ),
  values = rbind(
    V("injuries_avoided_count", "Injury crashes avoided", "crashes"),
    V("injury_cost_avoided_usd", "Injury cost avoided", "USD"),
    V("health_benefit_usd", "Health benefit of added riding", "USD"),
    V("wellbeing_pts", "Wellbeing (freedom, less fear)", "wellbeing pts")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(cy_discount_rate, horizon_yrs)
    c(
      injuries_avoided_count = injuries_avoided * af,
      injury_cost_avoided_usd = injuries_avoided * cy_injury_cost_usd * af,
      health_benefit_usd = extra_bike_trips * route_km * cy_health_usd_per_km * af,
      wellbeing_pts = (extra_bike_trips * cy_wellbeing_pts_per_new_trip +
        baseline_bike_trips_yr * cy_stress_relief_pts_per_trip * (0.3 + 0.7 * option_is_path)) * af
    )
  })
)
