# Neighbors who do not host the path
# Ontology: the road corridor is a quiet home environment; they bear noise and
# trespass without an easement payment, but their children may ride safely.

stakeholder <- new_stakeholder(
  id = "neighbors",
  label = "Neighbors (not hosting)",
  ontology = "Quiet home environment; bears nuisance without payment; cares about kids' independence.",
  dag_parents = list(
    noise_nuisance_pts = c("extra_bike_trips", "extra_walk_trips", "nb_households",
                           "nb_noise_pts_per_1000_trips", "nb_discount_rate", "horizon_yrs"),
    trespass_cost_usd = c("extra_bike_trips", "extra_walk_trips", "nb_trespass_usd_per_1000_trips",
                          "nb_discount_rate", "horizon_yrs"),
    property_value_usd = c("nb_households", "nb_home_value", "nb_property_effect_pct", "option_is_path"),
    kids_mobility_pts = c("nb_households", "nb_kid_mobility_pts",
                          "option_is_path", "nb_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("nb_households", 20, 80, "posnorm", "Households near the route, not hosting"),
    E("nb_noise_pts_per_1000_trips", 0.01, 0.1, "posnorm", "Nuisance per household per 1000 trips (pts)"),
    E("nb_trespass_usd_per_1000_trips", 5, 40, "posnorm", "Litter/trespass/parking cost per 1000 trips (USD)"),
    E("nb_home_value", 3e5, 7e5, "posnorm", "Typical home value (USD)"),
    E("nb_property_effect_pct", -0.02, 0.04, "norm", "Home value effect of path nearby (fraction)"),
    E("nb_kid_mobility_pts", 0.2, 1.5, "posnorm", "Wellbeing from kids riding safely (pts/household/yr)"),
    E("nb_discount_rate", 0.03, 0.08, "tnorm_0_1", "Discount rate (neighbors)")
  ),
  values = rbind(
    V("noise_nuisance_pts", "Noise and activity nuisance", "wellbeing pts"),
    V("trespass_cost_usd", "Trespass, litter, parking", "USD"),
    V("property_value_usd", "Home values", "USD"),
    V("kids_mobility_pts", "Children's independent mobility", "wellbeing pts")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(nb_discount_rate, horizon_yrs)
    trips <- extra_bike_trips + extra_walk_trips
    c(
      noise_nuisance_pts = -nb_households * trips / 1000 * nb_noise_pts_per_1000_trips * af,
      trespass_cost_usd = -trips / 1000 * nb_trespass_usd_per_1000_trips * af,
      property_value_usd = option_is_path * nb_households * nb_home_value * nb_property_effect_pct,
      kids_mobility_pts = nb_households * nb_kid_mobility_pts * (0.2 + 0.8 * option_is_path) * af
    )
  })
)
