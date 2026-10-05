# Turn MC output into one row per stakeholder x value x option -------------------
# certainty = how consistently the runs agree on the SIGN of the outcome:
#   |2 * max(P(>0), P(<0)) - 1|   (0 = coin flip, 1 = every run agrees)
# size_rel  = |median| / the larger of that value's biggest option median and its
#             95th-percentile |run|, so each value is scaled on its own units.

summarize_mc <- function(mc, stakeholders) {
  y <- mc$y
  rows <- lapply(names(y), function(nm) {
    parts <- strsplit(nm, "__", fixed = TRUE)[[1]]
    z <- y[[nm]]
    data.frame(stakeholder = parts[1], value = parts[2], option = parts[3],
               median = stats::median(z), q05 = stats::quantile(z, 0.05, names = FALSE),
               q95 = stats::quantile(z, 0.95, names = FALSE),
               p_pos = mean(z > 0), abs_q95 = stats::quantile(abs(z), 0.95, names = FALSE),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out$certainty <- abs(2 * pmax(out$p_pos, 1 - out$p_pos) - 1)
  key <- paste(out$stakeholder, out$value)
  ref <- pmax(ave(abs(out$median), key, FUN = max), ave(out$abs_q95, key, FUN = max))
  out$ref <- ref
  out$size_rel <- ifelse(ref > 0, abs(out$median) / ref, 0)

  meta <- do.call(rbind, lapply(stakeholders, function(s)
    cbind(stakeholder = s$id, stakeholder_label = s$label, s$values)))
  names(meta)[names(meta) == "label"] <- "value_label"
  merge(out, meta, by = c("stakeholder", "value"), sort = FALSE)
}
