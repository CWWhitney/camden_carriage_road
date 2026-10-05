# Compare the two liability scenarios ---------------------------------------------------
# protected: hosts keep Maine recreational-use protection (14 MRSA 159-A) and pay base liability costs.
# exposed:   paid permission is "consideration", the protection may not apply, host liability cost is multiplied.
# Raw USD values are compared (not indices), because index scales are set within each scenario.

compare_liability <- function(scen, stakeholders, out_dir) {
  lab <- setNames(options_tbl$label, options_tbl$option)
  # 1. Landowner net financial position, by option and scenario
  lo <- do.call(rbind, lapply(names(scen), function(nm) {
    d <- scen[[nm]]$summ
    d <- d[d$stakeholder == "landowners" & d$value == "net_financial_usd", ]
    data.frame(scenario = nm, option = d$option, label = lab[d$option], median = d$median,
               q05 = d$q05, q95 = d$q95, p_gain = d$p_pos, stringsAsFactors = FALSE)
  }))
  # 2. Landowner NPV, and who is Pareto-efficient (NPV view)
  npv_lo <- do.call(rbind, lapply(names(scen), function(nm) {
    m <- apply(scen[[nm]]$npv[, "landowners", ], 2, stats::median)
    data.frame(scenario = nm, option = names(m), landowner_npv_median = as.numeric(m))
  }))
  comp <- merge(lo, npv_lo, by = c("scenario", "option"))
  # 3. Game: most likely stable outcome at each Town weight
  g <- do.call(rbind, lapply(names(scen), function(nm) cbind(scenario = nm, scen[[nm]]$sens)))
  gd <- do.call(rbind, lapply(names(scen), function(nm) cbind(scenario = nm, scen[[nm]]$grid)))
  write.csv(gd, file.path(out_dir, "mechanism_design_grid_both_scenarios.csv"), row.names = FALSE)
  # Does a binding agreement make a path stable? Share of worlds with a path equilibrium, by Town weight.
  g$arm <- paste(g$scenario, g$mechanism, sep = " / ")
  p2 <- ggplot2::ggplot(g, ggplot2::aes(w_town_on_residents, prob_path_stable, color = arm, linetype = mechanism)) +
    ggplot2::geom_line(linewidth = 0.8) + ggplot2::geom_point() +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::labs(x = "Town's weight on residents", y = "Share of worlds in which some equilibrium builds a path",
                  color = "Liability / mechanism", title = "Does binding cost-sharing make a path stable?",
                  subtitle = "PLACEHOLDER INPUTS.") +
    ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(out_dir, "mechanism_comparison.png"), p2, width = 8, height = 5, dpi = 130, bg = "white")
  write.csv(comp, file.path(out_dir, "liability_comparison_landowners.csv"), row.names = FALSE)
  write.csv(g, file.path(out_dir, "liability_comparison_game.csv"), row.names = FALSE)

  comp$label <- factor(comp$label, levels = rev(options_tbl$label))
  p <- ggplot2::ggplot(comp, ggplot2::aes(median, label, color = scenario)) +
    ggplot2::geom_vline(xintercept = 0, color = "gray70") +
    ggplot2::geom_pointrange(ggplot2::aes(xmin = q05, xmax = q95),
                             position = ggplot2::position_dodge(width = 0.6)) +
    ggplot2::scale_color_manual(values = c(protected = "#2166AC", exposed = "#B2182B"),
                                labels = c(protected = "Protected (14 MRSA 159-A applies)",
                                           exposed = "Exposed (payments void protection)"), name = NULL) +
    ggplot2::labs(x = "Landowners' net financial position, PV (USD; median and 90% interval)", y = NULL,
                  title = "Does the liability question change the landowners' case?",
                  subtitle = "Both legal cases run as scenarios; legal status unresolved. PLACEHOLDER INPUTS.") +
    ggplot2::theme_minimal(base_size = 10) + ggplot2::theme(legend.position = "bottom")
  ggplot2::ggsave(file.path(out_dir, "liability_comparison.png"), p, width = 9, height = 5, dpi = 130, bg = "white")
  invisible(list(landowners = comp, game = g))
}
