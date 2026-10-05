# Stage 2: a community of agents who are also the decision-makers ---------------------
#
# Three players choose actions; the action profile maps to one of the Stage 1 physical
# configurations; payoffs come from the Stage 1 stakeholder models. The Snow Bowl is NOT a
# player: it is a Town-owned special revenue fund (see stakeholders/08_town.R), so it sits
# inside the Town player.
#
#   town        nothing | shoulders | path
#   landowners  refuse  | one_off   | annual | donate   (only matters if the Town proposes the path)
#   business    free_ride | contribute            (to host payments)
#
# Rules (placeholders to be debated with stakeholders):
#   * Town "nothing" -> status quo. Town "shoulders" -> widened shoulders (landowner action ignored).
#   * Town "path": landowners refuse -> only the 40% on public land is built, no host payments;
#     one_off -> carriage_path; annual -> path_annual; donate -> path_donated.
#   * A contributing business pays its share of host payments; a free-rider's share falls on the Town.
#   * Mechanism "voluntary": business chooses whether to contribute (host payments only).
#   * Mechanism "binding": a cost-sharing agreement signed before the path is built. If the Town builds a
#     path, business MUST pay its share of host payments and a share of the Town's net capital and
#     upkeep cost, so its action no longer matters. Shoulders are not covered.
#
# Payoff = the player's own group welfare index from Stage 1 (equal-weight mean of its scaled
# values). The Town also puts weight w_town on residents (cyclists, neighbors, drivers, hikers),
# because elected officials answer to voters, not only to the treasury. Nash analysis only compares
# a player's OWN payoffs across its own actions, so indices need not be comparable across players.

game_actions <- list(
  town       = c("nothing", "shoulders", "path"),
  landowners = c("refuse", "one_off", "annual", "donate"),
  business   = c("free_ride", "contribute")
)
game_players <- names(game_actions)
n_players <- length(game_players)
player_label <- c(town = "Town of Camden (incl. Snow Bowl)", landowners = "Landowners",
                  business = "Local business")

player_weights <- function(w_town = 0.5) {
  res <- c("cyclists", "neighbors", "drivers_residents", "hikers_walkers")
  list(town = c(town = 1, setNames(rep(w_town / length(res), length(res)), res)),
       landowners = c(landowners = 1),
       business = c(tourism_business = 1))
}

game_profiles <- function() {
  g <- expand.grid(game_actions, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  g$profile <- do.call(paste, c(g[game_players], sep = "/"))
  g
}

# Physical configuration used by a profile ("_bind" keys apply the binding agreement)
config_of <- function(town, landowners, business, binding = FALSE) {
  tb <- as.numeric(business == "contribute")
  suffix <- if (binding) "_bind" else ""
  if (town == "nothing") return(list(key = "status_quo", option = NA))
  if (town == "shoulders")
    return(list(key = paste0("shoulders_", tb), option = "shoulders", tb = tb, hosts = 1, binding = 0))
  if (binding) tb <- 1                                 # a binding agreement removes the choice
  if (landowners == "refuse")
    return(list(key = paste0("partial_nohost", suffix), option = "partial_path", tb = 1, hosts = 0,
                binding = as.numeric(binding)))
  opt <- c(one_off = "carriage_path", annual = "path_annual", donate = "path_donated")[[landowners]]
  list(key = paste0(opt, "_", tb, suffix), option = opt, tb = tb, hosts = 1,
       binding = as.numeric(binding))
}

outcome_label <- function(key) vapply(key, function(k) {
  bind <- grepl("_bind$", k); k0 <- sub("_bind$", "", k)
  tag <- if (bind) "; binding cost-sharing" else ""
  if (k0 == "status_quo") return("Status quo (nothing built)")
  if (k0 == "partial_nohost") return(paste0("Partial path on public land only (landowners refuse)", tag))
  flag <- sub(".*_([01])$", "\\1", k0)
  base <- sub("_[01]$", "", k0)
  who <- if (bind) "binding cost-sharing" else
    paste0("business ", ifelse(flag == "1", "pays", "free-rides"))
  nm <- c(shoulders = "Shoulders", carriage_path = "Path, one-off payment", path_annual = "Path, annual payments",
          path_donated = "Path, donated easement")[[base]]
  paste0(nm, "; ", who)
}, "", USE.NAMES = FALSE)

# Welfare index of every stakeholder, per MC run, for each distinct configuration -------
config_indices <- function(mc, summ, stakeholders, cfgs, liability = "protected") {
  x <- as.data.frame(mc$x)
  ref <- setNames(summ$ref, paste(summ$stakeholder, summ$value, sep = "__"))
  ids <- vapply(stakeholders, `[[`, "", "id")
  out <- lapply(cfgs, function(cfg) {
    if (is.na(cfg$option)) return(matrix(0, nrow(x), length(ids), dimnames = list(NULL, ids)))
    m <- matrix(0, nrow(x), length(ids), dimnames = list(NULL, ids))
    for (i in seq_len(nrow(x))) {
      p <- as.list(x[i, , drop = FALSE])
      d <- physical_delta(p, cfg$option, cfg$tb, cfg$hosts, liability, cfg$binding)
      for (s in stakeholders) {
        v <- s$outcomes(p, d)
        r <- ref[paste(s$id, names(v), sep = "__")]
        m[i, s$id] <- mean(ifelse(r > 0, v / r, 0))
      }
    }
    m
  })
  out
}

# Payoff array [run, a_1 ... a_K, player] ----------------------------------------------
# ix(): matrix index of a profile `a` (vector of action positions) in every run
ix <- function(n, a) cbind(seq_len(n), matrix(a, n, length(a), byrow = TRUE))

payoff_array <- function(cidx, profiles, weights, binding = FALSE) {
  n <- nrow(cidx[[1]])
  P <- array(0, dim = c(n, lengths(game_actions), n_players))
  for (r in seq_len(nrow(profiles))) {
    cfg <- do.call(config_of, c(as.list(profiles[r, game_players]), binding = binding))
    pos <- vapply(game_players, function(pl) match(profiles[[pl]][r], game_actions[[pl]]), 1L)
    for (k in seq_len(n_players)) {
      w <- weights[[game_players[k]]]
      P[cbind(ix(n, pos), k)] <- cidx[[cfg$key]][, names(w), drop = FALSE] %*% w
    }
  }
  P
}

# TRUE where a profile is a pure Nash equilibrium: [run, a_1 ... a_K] ------------------
nash_flags <- function(P, tol = 1e-9) {
  K <- length(dim(P)) - 2; n <- dim(P)[1]; na <- dim(P)[2:(K + 1)]
  ne <- array(TRUE, dim = c(n, na))
  grid <- as.matrix(expand.grid(lapply(na, seq_len)))
  for (r in seq_len(nrow(grid))) {
    a <- grid[r, ]
    for (k in seq_len(K)) {
      cur <- P[cbind(ix(n, a), k)]
      best <- cur
      for (alt in seq_len(na[k])) { b <- a; b[k] <- alt; best <- pmax(best, P[cbind(ix(n, b), k)]) }
      ne[ix(n, a)] <- ne[ix(n, a)] & (cur >= best - tol)
    }
  }
  ne
}

# Subgame-perfect equilibrium by backward induction; order = player order of moves. ----
# Ties go to the first-listed (most passive) action.
spe_profile <- function(Pm, order = seq_len(n_players), tol = 1e-9) {
  pay <- function(f) vapply(seq_len(n_players), function(k) Pm[rbind(c(f, k))], 0)
  solve <- function(fixed, depth) {
    if (depth > n_players) return(list(profile = fixed, pay = pay(fixed)))
    mover <- order[depth]
    best <- NULL
    for (a in seq_along(game_actions[[mover]])) {
      f <- fixed; f[mover] <- a
      res <- solve(f, depth + 1)
      if (is.null(best) || res$pay[mover] > best$pay[mover] + tol) best <- res
    }
    best
  }
  solve(rep(NA_integer_, n_players), 1)
}

profile_name <- function(pos) paste(mapply(function(pl, i) game_actions[[pl]][i], game_players, pos), collapse = "/")

# Everything for one value of the Town's weight on residents -------------------------
game_analysis <- function(cidx, w_town = 0.5, binding = FALSE) {
  prof <- game_profiles()
  P <- payoff_array(cidx, prof, player_weights(w_town), binding)
  ne_runs <- nash_flags(P)
  nr <- dim(ne_runs)[1]
  Pm <- apply(P, 2:(n_players + 2), mean)
  Pm_run <- array(Pm, dim = c(1, dim(Pm)))
  ne_mean <- nash_flags(Pm_run)
  ne_mean <- array(ne_mean, dim = dim(ne_mean)[-1])
  pos <- as.matrix(expand.grid(lapply(lengths(game_actions), seq_len)))
  tab <- do.call(rbind, lapply(seq_len(nrow(pos)), function(r) {
    a <- pos[r, ]
    data.frame(profile = profile_name(a),
               nash_prob = mean(ne_runs[ix(nr, a)]),
               nash_at_mean = ne_mean[rbind(a)],
               setNames(lapply(seq_len(n_players), function(k) Pm[rbind(c(a, k))]),
                        paste0("pay_", game_players)),
               stringsAsFactors = FALSE)
  }))
  tab$outcome <- vapply(seq_len(nrow(pos)), function(r)
    do.call(config_of, c(as.list(vapply(seq_len(n_players), function(k) game_actions[[k]][pos[r, k]], "")),
                         binding = binding))$key, "")
  # Collapse to outcomes (distinct physical configurations): many action profiles are equivalent,
  # e.g. when the Town does nothing every other action is irrelevant.
  ne_any <- lapply(split(seq_len(nrow(pos)), tab$outcome), function(rows)
    Reduce(`|`, lapply(rows, function(r) ne_runs[ix(nr, pos[r, ])])))
  out <- do.call(rbind, lapply(names(ne_any), function(k) {
    first <- tab[tab$outcome == k, ][1, ]
    data.frame(outcome = k, label = outcome_label(k), nash_prob = mean(ne_any[[k]]),
               nash_at_mean = any(tab$nash_at_mean[tab$outcome == k]),
               first[paste0("pay_", game_players)], stringsAsFactors = FALSE)
  }))
  M <- as.matrix(out[, paste0("pay_", game_players)])
  out$pareto_efficient_agents <- lengths(dominated_by(M)) == 0
  out <- out[order(-out$nash_prob), ]
  rownames(out) <- NULL
  perms <- gtools_perm(n_players)
  spe_orders <- do.call(rbind, lapply(seq_len(nrow(perms)), function(i) {
    ord <- perms[i, ]
    r <- spe_profile(Pm, ord)
    data.frame(order = paste(game_players[ord], collapse = " > "), spe = profile_name(r$profile),
               stringsAsFactors = FALSE)
  }))
  spe_orders$outcome <- vapply(strsplit(spe_orders$spe, "/", fixed = TRUE),
                               function(a) do.call(config_of, c(as.list(a), binding = binding))$key, "")
  spe_orders$outcome_label <- outcome_label(spe_orders$outcome)
  # In how many worlds does at least one equilibrium involve building a path (town = path)?
  path_ne <- vapply(seq_len(nr), function(i) any(ne_runs[i, 3, , ]), TRUE)
  sq_ne <- vapply(seq_len(nr), function(i) any(ne_runs[i, 1, , ]), TRUE)
  list(table = tab, outcomes = out, spe_orders = spe_orders, w_town = w_town, binding = binding,
       path_ne_prob = mean(path_ne), status_quo_ne_prob = mean(sq_ne),
       spe_default = profile_name(spe_profile(Pm)$profile))
}

gtools_perm <- local({
  perms <- function(n) {
    if (n == 1) return(matrix(1))
    p <- perms(n - 1)
    do.call(rbind, lapply(seq_len(n), function(i) cbind(i, ifelse(p >= i, p + 1, p))))
  }
  function(n) perms(n)
})

# Mean welfare index of ALL groups at a profile (bystanders included) ------------------
profile_welfare <- function(cidx, profile, binding = FALSE) {
  a <- strsplit(profile, "/", fixed = TRUE)[[1]]
  cfg <- config_of(a[1], a[2], a[3], binding)
  colMeans(cidx[[cfg$key]])
}

# Plots --------------------------------------------------------------------------------
plot_nash_probability <- function(res, min_prob = 0.02) {
  d <- res$outcomes[res$outcomes$nash_prob >= min_prob | res$outcomes$nash_at_mean, ]
  d <- d[order(d$nash_prob), ]
  d$label <- factor(d$label, levels = d$label)
  ggplot2::ggplot(d, ggplot2::aes(nash_prob, label, fill = pareto_efficient_agents)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = ifelse(nash_at_mean, "stable at mean payoffs", "")),
                       hjust = -0.05, size = 3) +
    ggplot2::scale_fill_manual(values = c(`TRUE` = "#2166AC", `FALSE` = "#B2182B"),
                               labels = c(`TRUE` = "yes", `FALSE` = "no (all three could do better)"),
                               name = "Pareto-efficient\namong the three players") +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = ggplot2::expansion(mult = c(0, 0.35))) +
    ggplot2::labs(x = "Share of Monte Carlo runs in which this outcome is a pure Nash equilibrium", y = NULL,
                  title = "Which outcomes are stable?",
                  subtitle = paste0("Mechanism: ", if (res$binding) "binding cost-sharing" else "voluntary contributions",
                                    ". Town weight on residents = ", res$w_town, ". PLACEHOLDER INPUTS.")) +
    ggplot2::theme_minimal(base_size = 10)
}

plot_equilibrium_welfare <- function(cidx, profiles, stakeholders, w_town, binding = FALSE) {
  profiles <- unique(profiles)
  d <- do.call(rbind, lapply(profiles, function(pr) {
    v <- profile_welfare(cidx, pr, binding)
    data.frame(profile = pr, stakeholder = names(v), index = as.numeric(v))
  }))
  lab <- setNames(vapply(stakeholders, `[[`, "", "label"), vapply(stakeholders, `[[`, "", "id"))
  d$group <- factor(lab[d$stakeholder], levels = rev(unname(lab)))
  d$profile <- factor(gsub("/", "/\n", d$profile), levels = gsub("/", "/\n", profiles))
  ggplot2::ggplot(d, ggplot2::aes(profile, group, fill = index)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%+.2f", index)), size = 2.8) +
    ggplot2::scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC",
                                  midpoint = 0, limits = c(-1, 1), name = "Welfare\nindex") +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(x = NULL, y = NULL, title = "What the stable outcomes do to everyone, including bystanders",
                  subtitle = "Columns: town/landowners/business actions. PLACEHOLDER INPUTS.") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), axis.text.x = ggplot2::element_text(size = 7))
}

# All distinct configurations needed by both mechanisms ---------------------------------
all_configs <- function() {
  prof <- game_profiles()
  cf <- c(lapply(seq_len(nrow(prof)), function(r) do.call(config_of, as.list(prof[r, game_players]))),
          lapply(seq_len(nrow(prof)), function(r) do.call(config_of, c(as.list(prof[r, game_players]), binding = TRUE))))
  cf <- cf[!duplicated(vapply(cf, `[[`, "", "key"))]
  setNames(cf, vapply(cf, `[[`, "", "key"))
}

# Design of the binding agreement: sweep the business's capital share and outside grant money ------
# For each pair, and each way landowners could host, how often do all three players end up
# better off than under the status quo, and what is the weakest player's mean payoff?
# (Grants are the "outside money" question in GAME_PLAN.md section 12: they cut the Town's cost.)
mechanism_grid <- function(mc, summ, stakeholders, liability = "protected", n = 500, w_town = 0.5,
                           tb_grid = c(0, 0.05, 0.1, 0.2, 0.3), grant_grid = c(0.2, 0.4, 0.6, 0.8)) {
  x <- as.data.frame(mc$x)[seq_len(n), ]
  forms <- c(one_off = "carriage_path", annual = "path_annual", donate = "path_donated")
  w <- player_weights(w_town)
  rows <- list()
  for (tb in tb_grid) for (gs in grant_grid) {
    xx <- x; xx$mech_capshare_business <- tb; xx$grant_share <- gs
    cf <- lapply(forms, function(o) list(option = o, tb = 1, hosts = 1, binding = 1))
    ci <- config_indices(list(x = xx), summ, stakeholders, cf, liability)
    for (f in names(forms)) {
      pay <- vapply(game_players, function(pl) as.numeric(ci[[f]][, names(w[[pl]]), drop = FALSE] %*% w[[pl]]), numeric(n))
      rows[[length(rows) + 1]] <- data.frame(
        business_capital_share = tb, grant_share = gs, landowner_form = f,
        setNames(as.list(colMeans(pay)), paste0("mean_pay_", game_players)),
        p_all_gain = mean(rowSums(pay > 0) == n_players),
        weakest_mean_payoff = min(colMeans(pay)))
    }
  }
  do.call(rbind, rows)
}

plot_mechanism_grid <- function(g) {
  lv <- c("Landowners: one-off payment", "Landowners: annual payments", "Landowners: donated easement")
  g$form <- factor(c(one_off = lv[1], annual = lv[2], donate = lv[3])[g$landowner_form], levels = lv)
  ggplot2::ggplot(g, ggplot2::aes(factor(business_capital_share), factor(grant_share), fill = p_all_gain)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.0f%%", 100 * p_all_gain)), size = 3) +
    ggplot2::facet_wrap(~form) +
    ggplot2::scale_fill_gradient(low = "white", high = "#2166AC", limits = c(0, 1), name = "Share of worlds\nwhere all three gain") +
    ggplot2::labs(x = "Business's share of the Town's net capital and upkeep cost",
                  y = "Share of capital cost met by outside grants",
                  title = "Which binding terms leave everyone better off?",
                  subtitle = "All three = Town (incl. Snow Bowl), landowners, business, each better off than the status quo. PLACEHOLDER INPUTS.") +
    ggplot2::scale_x_discrete(labels = function(x) sprintf("%.0f%%", 100 * as.numeric(x))) +
    ggplot2::scale_y_discrete(labels = function(x) sprintf("%.0f%%", 100 * as.numeric(x))) +
    ggplot2::guides(fill = ggplot2::guide_colorbar(title.position = "top", barwidth = 12)) +
    ggplot2::theme_minimal(base_size = 10) + ggplot2::theme(legend.position = "bottom", panel.grid = ggplot2::element_blank())
}
