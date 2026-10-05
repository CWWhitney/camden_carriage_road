# Keeney-style consequence matrix as a bubble plot --------------------------------
# rows = values clustered by stakeholder, columns = options
# color = sign of median (blue gain, red loss); size = magnitude on the value's own
# scale; transparency = certainty about the sign (solid = more certain)

bubble_matrix <- function(summ, stakeholders, which = NULL, options = NULL, title = NULL) {
  if (!is.null(which)) summ <- summ[summ$stakeholder %in% which, ]
  if (!is.null(options)) {
    summ <- summ[summ$option %in% options, ]
    keep <- ave(summ$size_rel, summ$stakeholder, summ$value, FUN = max) > 0   # drop rows empty in every shown option
    summ <- summ[keep, ]
  }
  lab <- setNames(options_tbl$label, options_tbl$option)
  lvl <- if (is.null(options)) options_tbl$label else lab[options]
  summ$option_label <- factor(lab[summ$option], levels = lvl)
  summ$stakeholder_label <- factor(summ$stakeholder_label,
                                   levels = vapply(stakeholders, `[[`, "", "label"))
  summ$row <- factor(paste0(summ$value_label, " (", summ$unit, ")"))
  summ$row <- factor(summ$row, levels = rev(unique(summ$row[order(summ$stakeholder_label)])))
  summ$gain <- ifelse(summ$median >= 0, "gain", "loss")
  summ$alpha <- 0.2 + 0.8 * summ$certainty

  ggplot2::ggplot(summ, ggplot2::aes(option_label, row)) +
    ggplot2::geom_point(ggplot2::aes(size = size_rel, fill = gain, alpha = alpha),
                        shape = 21, color = "gray30", stroke = 0.3) +
    ggplot2::scale_size_area(max_size = 9, limits = c(0, 1), guide = "none") +
    ggplot2::scale_x_discrete(position = "top", labels = function(x) stringr_wrap(x, 18)) +
    ggplot2::scale_alpha_identity() +
    ggplot2::scale_fill_manual(values = c(gain = "#2166AC", loss = "#B2182B"),
                               name = "Median outcome vs status quo") +
    ggplot2::facet_grid(stakeholder_label ~ ., scales = "free_y", space = "free_y", switch = "y") +
    ggplot2::labs(x = NULL, y = NULL,
                  title = if (is.null(title)) "Camden to the Snow Bowl: one decision, many ontologies" else title,
                  subtitle = paste("Size = magnitude on each value's own scale.\nTransparency = certainty about the sign",
                                   "\n(solid = more certain). PLACEHOLDER INPUTS."),
                  caption = "Outcomes are discounted changes vs status quo; each stakeholder uses its own discount rate.") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(strip.placement = "outside",
                   strip.text.y.left = ggplot2::element_text(angle = 0, hjust = 1, face = "bold"),
                   panel.grid.major.x = ggplot2::element_blank(),
                   axis.text.x.top = ggplot2::element_text(size = 8, vjust = 0),
                   legend.position = "bottom")
}

# wrap a label at about `width` characters (base R, no extra package)
stringr_wrap <- function(x, width = 18) vapply(x, function(z) paste(strwrap(z, width), collapse = "\n"), "", USE.NAMES = FALSE)
