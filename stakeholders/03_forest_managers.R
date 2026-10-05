# Forest managers / land trust
# Ontology: the forest is a working, stewarded asset. Clearing and edge cost
# timber value and invasive-control effort; a corridor can improve access.

stakeholder <- new_stakeholder(
  id = "forest_managers",
  label = "Forest managers / land trust",
  ontology = "Forest as stewarded working asset; cares about stand value, invasives, access and enforcement burden.",
  dag_parents = list(
    stand_value_loss_usd = c("clear_ha", "fm_timber_value_per_ha"),
    access_saving_usd = c("fm_access_saving_usd_yr", "option_is_path", "fm_discount_rate", "horizon_yrs"),
    management_cost_usd = c("edge_ha", "fm_invasives_usd_per_edge_ha_yr", "extra_bike_trips", "extra_walk_trips",
                            "fm_enforcement_usd_per_1000_trips", "fm_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("fm_timber_value_per_ha", 3000, 9000, "posnorm", "Standing timber and site value (USD/ha)"),
    E("fm_access_saving_usd_yr", 0, 3000, "unif", "Annual saving from a maintained corridor for operations (USD/yr)"),
    E("fm_invasives_usd_per_edge_ha_yr", 20, 120, "posnorm", "Invasive control per edge hectare (USD/ha/yr)"),
    E("fm_enforcement_usd_per_1000_trips", 5, 30, "posnorm", "Signage, patrols, repairs per 1000 trips (USD)"),
    E("fm_discount_rate", 0.03, 0.07, "tnorm_0_1", "Discount rate (forest managers)")
  ),
  values = rbind(
    V("stand_value_loss_usd", "Stand value lost", "USD"),
    V("access_saving_usd", "Operational access savings", "USD"),
    V("management_cost_usd", "Invasives and user management cost", "USD")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(fm_discount_rate, horizon_yrs)
    c(
      stand_value_loss_usd = -clear_ha * fm_timber_value_per_ha,
      access_saving_usd = option_is_path * fm_access_saving_usd_yr * af,
      management_cost_usd = -(fm_invasives_usd_per_edge_ha_yr * edge_ha +
        fm_enforcement_usd_per_1000_trips * (extra_bike_trips + extra_walk_trips) / 1000) * af
    )
  })
)
