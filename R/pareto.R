# Stage 1 welfare view: one policy-maker, every group's welfare under every option.
#
# Each value is scaled by its own reference (summ$ref, see summarize.R) so a run's
# signed relative outcome lies roughly in [-1, 1]. A stakeholder's welfare index in
# a run is the EQUAL-WEIGHT mean of its values' relative outcomes (an assumption:
# groups could weight their own values differently). status_quo is a row of zeros.
# An option is Pareto-dominated if another option (status_quo included) is at least
# as good for every group and strictly better for one.

welfare_indices <- function(mc, summ, stakeholders) {
  y <- mc$y
  opts <- c("status_quo", options_tbl$option)
  n <- nrow(y)
  ids <- vapply(stakeholders, `[[`, "", "id")
  idx <- array(0, dim = c(n, length(ids), length(opts)), dimnames = list(NULL, ids, opts))
  for (s in stakeholders) for (o in options_tbl$option) {
    cols <- vapply(s$values$value, function(v) {
      r <- summ$ref[summ$stakeholder == s$id & summ$value == v & summ$option == o]
      if (r > 0) y[[paste(s$id, v, o, sep = "__")]] / r else rep(0, n)
    }, numeric(n))
    idx[, s$id, o] <- rowMeans(matrix(cols, nrow = n))
  }
  idx
}

dominated_by <- function(M) {          # M: options x groups; returns list of dominating options
  lapply(seq_len(nrow(M)), function(i) {
    which(vapply(seq_len(nrow(M)), function(j) j != i && all(M[j, ] >= M[i, ]) && any(M[j, ] > M[i, ]),
                 logical(1)))
  })
}

pareto_summary <- function(idx) {
  opts <- dimnames(idx)[[3]]
  med <- apply(idx, c(2, 3), stats::median)          # groups x options
  M <- t(med)                                        # options x groups
  dom_med <- dominated_by(M)
  dom_runs <- matrix(FALSE, dim(idx)[1], length(opts), dimnames = list(NULL, opts))
  for (r in seq_len(dim(idx)[1])) {
    Mr <- t(idx[r, , ])
    dom_runs[r, ] <- lengths(dominated_by(Mr)) > 0
  }
  data.frame(
    option = opts,
    label = c("Status quo", options_tbl$label),
    groups_better_off = colSums(med > 0.02),
    groups_worse_off = colSums(med < -0.02),
    pareto_efficient = lengths(dom_med) == 0,
    dominated_by = vapply(dom_med, function(j) paste(opts[j], collapse = ", "), ""),
    prob_dominated = colMeans(dom_runs),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

index_long <- function(idx) {
  d <- as.data.frame.table(idx, responseName = "index", stringsAsFactors = FALSE)
  names(d)[1:3] <- c("run", "stakeholder", "option")
  d
}

# Heatmap: median welfare index of each group under each option --------------
welfare_heatmap <- function(idx, stakeholders, psum, metric = c("index", "npv")) {
  metric <- match.arg(metric)
  med <- apply(idx, c(2, 3), stats::median)
  d <- as.data.frame.table(med, responseName = "index", stringsAsFactors = FALSE)
  names(d)[1:2] <- c("stakeholder", "option")
  lab <- setNames(vapply(stakeholders, `[[`, "", "label"), vapply(stakeholders, `[[`, "", "id"))
  d$group <- factor(lab[d$stakeholder], levels = rev(unname(lab)))
  olab <- setNames(psum$label, psum$option)
  d$opt <- factor(paste0(olab[d$option], ifelse(psum$pareto_efficient[match(d$option, psum$option)], " *", "")),
                  levels = paste0(psum$label, ifelse(psum$pareto_efficient, " *", "")))
  d$fill <- if (metric == "npv") d$index / ave(abs(d$index), d$group, FUN = max) else d$index
  d$fill[is.nan(d$fill)] <- 0
  ggplot2::ggplot(d, ggplot2::aes(opt, group, fill = fill)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::geom_text(ggplot2::aes(label = if (metric == "npv") sprintf("%+.0fk", index / 1000) else sprintf("%+.2f", index)), size = 2.8) +
    ggplot2::scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC", midpoint = 0,
                                  limits = c(-1, 1),
                                  name = if (metric == "npv") "Share of group's\nlargest effect" else "Welfare\nindex") +
    ggplot2::scale_x_discrete(position = "top", guide = ggplot2::guide_axis(angle = 30)) +
    ggplot2::labs(x = NULL, y = NULL,
                  title = "Who gains and who loses under each option",
                  subtitle = if (metric == "npv") "Median within-group NPV vs status quo, thousands of USD-equivalent (color scaled within each row).\n* = Pareto-efficient. PLACEHOLDER INPUTS." else "Median welfare index vs status quo (equal-weight mean of each group's scaled values).\n* = Pareto-efficient. PLACEHOLDER INPUTS.") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), plot.margin = ggplot2::margin(10, 40, 5, 5))
}

# Two-axis view: one group vs everyone else, with the Pareto frontier ----------
pareto_plot <- function(idx, x_group = "landowners", psum, metric = c("index", "npv")) {
  metric <- match.arg(metric)
  others <- setdiff(dimnames(idx)[[2]], x_group)
  runs <- do.call(rbind, lapply(dimnames(idx)[[3]], function(o)
    data.frame(option = o, x = idx[, x_group, o], y = rowMeans(idx[, others, o, drop = FALSE]))))
  pts <- stats::aggregate(cbind(x, y) ~ option, runs, stats::median)
  pts$label <- psum$label[match(pts$option, psum$option)]
  M <- as.matrix(pts[, c("x", "y")])
  eff <- lengths(dominated_by(M)) == 0
  pts$eff <- eff
  fr <- pts[eff, ][order(pts$x[eff]), ]
  runs <- runs[sample(nrow(runs), min(nrow(runs), 6000)), ]
  ggplot2::ggplot() +
    ggplot2::geom_point(data = runs, ggplot2::aes(x, y, color = option), alpha = 0.06, size = 0.6) +
    ggplot2::geom_step(data = fr, ggplot2::aes(x, y), direction = "vh", color = "gray30", linetype = 2) +
    ggplot2::geom_point(data = pts, ggplot2::aes(x, y, color = option, shape = eff),
                        size = 3) +
    ggrepel::geom_text_repel(data = pts, ggplot2::aes(x, y, label = label), size = 3) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70") + ggplot2::geom_vline(xintercept = 0, color = "gray70") +
    ggplot2::coord_cartesian(xlim = range(pts$x) + c(-0.1, 0.1) * max(diff(range(pts$x)), 0.1),
                             ylim = range(pts$y) + c(-0.25, 0.25) * max(diff(range(pts$y)), 0.1)) +
    ggplot2::scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1), name = "Pareto-efficient\n(in this 2-axis view)") +
    ggplot2::guides(color = "none") +
    ggplot2::labs(x = paste(if (metric == "npv") "Within-group NPV (USD-equiv.):" else "Welfare index:", x_group),
                  y = if (metric == "npv") "Within-group NPV: mean of all other groups" else "Welfare index: mean of all other groups",
                  title = paste(x_group, "versus everyone else"),
                  subtitle = "Dots = median; cloud = Monte Carlo runs; dashed line = frontier. PLACEHOLDER INPUTS.") +
    ggplot2::theme_minimal(base_size = 10)
}
