# Tourism and local business
# Ontology: the route is a visitor flow. Counts margin, seasonal jobs and the
# destination brand; discounts heavily (short planning horizons).

stakeholder <- new_stakeholder(
  id = "tourism_business",
  label = "Tourism and local business",
  ontology = "Visitor flow and brand; counts margin and jobs; short horizon.",
  dag_parents = list(
    business_margin_usd = c("extra_bike_trips", "tb_visitor_share", "tb_spend_per_visitor_day",
                            "tb_margin", "tb_discount_rate", "horizon_yrs"),
    jobs_fte = c("extra_bike_trips", "tb_visitor_share", "tb_spend_per_visitor_day", "tb_revenue_per_fte"),
    destination_brand_pts = c("trail_km_new", "tb_brand_pts_per_km", "tb_discount_rate", "horizon_yrs"),
    capital_contribution_usd = c("public_capital_cost", "annual_maint", "town_cost_share", "capshare_business",
                                 "tb_discount_rate", "horizon_yrs"),
    payment_contribution_usd = c("payment_oneoff", "payment_annual", "share_business",
                                  "tb_discount_rate", "horizon_yrs")
  ),
  inputs = rbind(
    E("tb_visitor_share", 0.2, 0.5, "tnorm_0_1", "Share of added bike trips by non-local visitors"),
    E("tb_spend_per_visitor_day", 25, 90, "posnorm", "Local spend per visitor-day (USD)"),
    E("tb_margin", 0.1, 0.25, "tnorm_0_1", "Net margin on that spend"),
    E("tb_revenue_per_fte", 6e4, 1.2e5, "posnorm", "Revenue supporting one seasonal FTE (USD)"),
    E("tb_brand_pts_per_km", 0.2, 2, "posnorm", "Destination brand value per km of safe path per yr (pts)"),
    E("tb_discount_rate", 0.05, 0.12, "tnorm_0_1", "Discount rate (business)")
  ),
  values = rbind(
    V("business_margin_usd", "Added business margin", "USD"),
    V("jobs_fte", "Seasonal jobs supported", "FTE"),
    V("destination_brand_pts", "Destination brand", "brand pts"),
    V("payment_contribution_usd", "Share of landowner payments", "USD"),
    V("capital_contribution_usd", "Share of path capital and upkeep (binding agreement)", "USD")
  ),
  outcomes = function(p, d) with(c(p, d), {
    af <- annuity(tb_discount_rate, horizon_yrs)
    spend <- extra_bike_trips * tb_visitor_share * tb_spend_per_visitor_day
    c(
      business_margin_usd = spend * tb_margin * af,
      jobs_fte = spend / tb_revenue_per_fte,
      destination_brand_pts = trail_km_new * tb_brand_pts_per_km * af,
      capital_contribution_usd = -(public_capital_cost + annual_maint * af) * town_cost_share * capshare_business,
      payment_contribution_usd = -(payment_oneoff + payment_annual * af) * share_business
    )
  })
)
