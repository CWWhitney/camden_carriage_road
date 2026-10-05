# Town of Camden (municipal finance and services)
# Ontology: a budget line, a tax base and an emergency-response burden.

stakeholder <- new_stakeholder(
  id = "town_finance",
  label = "Town of Camden",
  ontology = "Budget and tax base; counts net public cost, tax gain and emergency-service savings.",
  dag_parents = list(
    net_capital_maint_cost_usd = c("public_capital_cost", "town_cost_share", "capshare_snowbowl", "capshare_business", "annual_maint",
                                   "tw_discount_rate", "horizon_yrs"),
    tax_revenue_gain_usd = c("trail_km_new", "tw_assessed_uplift_per_km", "tw_tax_rate",
                             "tw_discount_rate", "horizon_yrs"),
    ems_savings_usd = c("injuries_avoided", "tw_ems_cost_per_injury", "tw_discount_rate", "horizon_yrs"),
    winter_maintenance_cost_usd = c("trail_km_new", "tw_winter_maint_per_km_yr",
                                    "tw_discount_rate", "horizon_yrs"),
    payment_contribution_usd = c("payment_oneoff", "payment_annual", "share_snowbowl",
                                  "share_business", "tw_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("tw_assessed_uplift_per_km", 2e4, 1.5e5, "posnorm", "Added assessed value per km of path (USD/km)"),
    E("tw_tax_rate", 0.01, 0.02, "tnorm_0_1", "Effective property tax rate"),
    E("tw_ems_cost_per_injury", 1500, 6000, "posnorm", "Public EMS cost per injury crash (USD)"),
    E("tw_winter_maint_per_km_yr", 500, 3000, "posnorm", "Winter maintenance of path per km (USD/yr)"),
    E("tw_discount_rate", 0.02, 0.05, "tnorm_0_1", "Discount rate (town)")
  ),
  values = rbind(
    V("net_capital_maint_cost_usd", "Capital and upkeep cost to town", "USD"),
    V("tax_revenue_gain_usd", "Added tax revenue", "USD"),
    V("ems_savings_usd", "Emergency-response savings", "USD"),
    V("winter_maintenance_cost_usd", "Winter maintenance", "USD"),
    V("payment_contribution_usd", "Share of landowner payments", "USD")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(tw_discount_rate, horizon_yrs)
    c(
      net_capital_maint_cost_usd = -(public_capital_cost + annual_maint * af) * town_cost_share *
        (1 - capshare_snowbowl - capshare_business),
      tax_revenue_gain_usd = trail_km_new * tw_assessed_uplift_per_km * tw_tax_rate * af,
      ems_savings_usd = injuries_avoided * tw_ems_cost_per_injury * af,
      winter_maintenance_cost_usd = -trail_km_new * tw_winter_maint_per_km_yr * af,
      payment_contribution_usd = -(payment_oneoff + payment_annual * af) * (1 - share_snowbowl - share_business)
    )
  })
)
