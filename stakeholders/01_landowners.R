# Landowners hosting the path (e.g. parcels off Hosmer Pond Road / Emery Way)
# Ontology: land is home, legacy and an asset. Giving up a strip is a trade of
# money, privacy and liability against pride, safety and rising neighbor value.

stakeholder <- new_stakeholder(
  id = "landowners",
  label = "Landowners hosting the path",
  ontology = "Land as home, legacy and asset; discounts heavily; values privacy and control.",
  dag_parents = list(
    net_financial_usd = c("land_ha", "payment_oneoff", "payment_annual", "lo_land_value_per_ha",
                          "lo_uplift_pct", "lo_parcel_value", "lo_n_households", "host_share",
                          "lo_liability_cost_yr", "liability_mult", "donated", "donation_tax_benefit_share",
                          "option_is_path", "lo_discount_rate", "horizon_yrs"),
    privacy_wellbeing_pts = c("extra_bike_trips", "extra_walk_trips", "lo_n_households", "host_share",
                              "lo_privacy_pts_per_1000_trips", "lo_discount_rate", "horizon_yrs"),
    legacy_pride_pts = c("lo_pride_pts", "lo_donation_pride_pts", "donated", "lo_n_households", "host_share", "option_is_path",
                         "lo_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("lo_n_households", 3, 10, "posnorm", "Households hosting the path"),
    E("lo_land_value_per_ha", 8000, 40000, "posnorm", "Value of land given up (USD/ha)"),
    E("lo_parcel_value", 3e5, 9e5, "posnorm", "Value of a remaining home parcel (USD)"),
    E("lo_uplift_pct", 0, 0.06, "unif", "Parcel value uplift from path access (fraction)"),
    E("lo_liability_cost_yr", 100, 600, "posnorm", "Extra insurance/liability cost per household (USD/yr)"),
    E("lo_privacy_pts_per_1000_trips", 0.05, 0.4, "posnorm", "Wellbeing lost per household per 1000 passing trips (pts)"),
    E("lo_pride_pts", 0.5, 3, "posnorm", "Wellbeing from contributing to the community (pts/household/yr)"),
    E("lo_donation_pride_pts", 0.5, 3, "posnorm", "Extra wellbeing from donating the easement (pts/household/yr)"),
    E("lo_discount_rate", 0.04, 0.10, "tnorm_0_1", "Discount rate (landowners)")
  ),
  values = rbind(
    V("net_financial_usd", "Net financial position", "USD"),
    V("privacy_wellbeing_pts", "Privacy loss", "wellbeing pts"),
    V("legacy_pride_pts", "Legacy and community pride", "wellbeing pts")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(lo_discount_rate, horizon_yrs)
    c(
      net_financial_usd = payment_oneoff + payment_annual * af - land_ha * lo_land_value_per_ha +
        donated * donation_tax_benefit_share * lo_land_value_per_ha * land_ha +
        option_is_path * lo_uplift_pct * lo_parcel_value * lo_n_households * host_share -
        option_is_path * lo_liability_cost_yr * liability_mult * lo_n_households * host_share * af,
      privacy_wellbeing_pts = -lo_n_households * host_share * (extra_bike_trips + extra_walk_trips) / 1000 *
        lo_privacy_pts_per_1000_trips * af,
      legacy_pride_pts = lo_n_households * host_share * (lo_pride_pts * (0.3 + 0.7 * option_is_path) +
                                                          donated * lo_donation_pride_pts) * af
    )
  })
)
