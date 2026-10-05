# Climate and future residents
# Ontology: today's build is a long-lived commitment. Counts embodied vs
# avoided emissions, independence for tomorrow's young riders, and the risk
# that a path invites development pressure on the remaining forest.

stakeholder <- new_stakeholder(
  id = "climate_future",
  label = "Climate and future residents",
  ontology = "Long-run commitments; near-zero discounting; counts net emissions, youth mobility and development pressure.",
  dag_parents = list(
    net_tco2e_avoided = c("car_km_avoided", "cl_kgco2_per_car_km", "trail_km_new", "shoulder_km",
                          "cl_construction_tco2e_per_km_path", "cl_shoulder_construction_ratio",
                          "cl_discount_rate", "horizon_yrs"),
    climate_value_usd = c("net_tco2e_avoided", "cl_social_cost_usd_per_tco2e"),
    youth_mobility_pts = c("trail_km_new", "cl_youth_pts_per_km", "cl_discount_rate", "horizon_yrs"),
    development_pressure_ha = c("option_is_path", "cl_dev_pressure_ha")
  ),
  inputs = rbind(
    E("cl_kgco2_per_car_km", 0.15, 0.30, "posnorm", "Emissions per car km (kgCO2e)"),
    E("cl_construction_tco2e_per_km_path", 20, 120, "posnorm", "Embodied emissions of building the path (tCO2e/km)"),
    E("cl_shoulder_construction_ratio", 0.2, 0.5, "tnorm_0_1", "Shoulder embodied emissions as a fraction of path"),
    E("cl_social_cost_usd_per_tco2e", 50, 250, "posnorm", "Social cost of carbon (USD/tCO2e)"),
    E("cl_youth_pts_per_km", 0.2, 1.2, "posnorm", "Independent mobility for young riders per km of path per yr (pts)"),
    E("cl_dev_pressure_ha", 0, 5, "unif", "Extra forest developed because of improved access (ha)"),
    E("cl_discount_rate", 0, 0.02, "unif", "Discount rate (future residents: near zero)")
  ),
  values = rbind(
    V("net_tco2e_avoided", "Net emissions avoided", "tCO2e"),
    V("climate_value_usd", "Value of net emissions avoided", "USD"),
    V("youth_mobility_pts", "Youth independent mobility", "wellbeing pts"),
    V("development_pressure_ha", "Development pressure on forest", "ha")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(cl_discount_rate, horizon_yrs)
    embodied <- cl_construction_tco2e_per_km_path *
      (trail_km_new + shoulder_km * cl_shoulder_construction_ratio)
    net <- car_km_avoided * cl_kgco2_per_car_km / 1000 * af - embodied
    c(
      net_tco2e_avoided = net,
      climate_value_usd = net * cl_social_cost_usd_per_tco2e,
      youth_mobility_pts = trail_km_new * cl_youth_pts_per_km * af,
      development_pressure_ha = -option_is_path * cl_dev_pressure_ha
    )
  })
)
