#' Random generation for the Birnbaum-Saunders distribution.
#'
#'@description The random generation for the Birnbaum-Saunders distribution.
#'
#'@usage rbs(n, alpha, beta)
#'
#' @param n Sample size.
#' @param alpha Shape parameter.
#' @param beta Scale parameter.
#'
#' @return A sample of size n from the Birnbaum-Saunders distribution.
#' @export
#'

rbs <- function(n, alpha, beta) {
  if (n == 1) {
    x <- numeric()
    for (i in 1:length(alpha)) {
      z <- rnorm(1)
      x[i] <- (beta[i]/4)*(alpha[i]*z + sqrt((alpha[i]*z)^2 + 4))^2
    }
  } else if (n > 1 && length(alpha) == 1 && length(beta) == 1) {
    z <- rnorm(n)
    x <- (beta/4)*(alpha*z + sqrt((alpha*z)^2 + 4))^2
  }
  return(x)
}


#' Random generation for the posterior distribution of the Birnbaum-Saunders/inverse-gamma model.
#'
#'@description The function
#'
#'
#'@usage rpost.bs(N, x, a1, b1, a2, b2, r)
#'
#' @param N Number of observations.
#' @param x Observed values of the model.
#' @param a1 Hyperparameter of the prior distribution for beta.
#' @param b1 Hyperparameter of the prior distribution for beta.
#' @param a2 Hyperparameter of the prior distribution for alpha^2.
#' @param b2 Hyperparameter of the prior distribution for alpha^2.
#' @param r A constant for the sampling method.
#'
#' @note We adapted the available R script (Supplementary Material) of Wang, Sun & Park (2016, Comp. Stat.)
#'
#' @return A random sample of the posterior distribution of the model Birnbaum-Saunders/inverse-gamma.
#' @export
#'

rpost.bs <- function(N, x, a1, b1, a2, b2, r) {
  n <- length(x)
  betaLog <- function(b) {
    1/(r + 1) * (-(n + a1 + 1) * log(b) - b1/b + sum(log((b/x)^(1/2) +
                                                           (b/x)^(3/2))) - ((n + 1)/2 + a2) * log(sum(1/2 * (x/b + b/x - 2)) + b2))
  }
  betafLog <- function(b) {
    log(b) + r/(r + 1) * (-(n + a1 + 1) * log(b) - b1/b + sum(log((b/x)^(1/2)
                                                                  + (b/x)^(3/2))) - ((n + 1)/2 + a2) * log(sum(1/2 * (x/b + b/x - 2)) + b2))
  }
  a.max <- optimize(betaLog, lower = 0, upper = 1E20, maximum = TRUE)$objective
  b.max <- optimize(betafLog, lower = 0, upper = 1E20, maximum = TRUE)$objective
  a.val <- b.val <- rep(0, N)
  for (j in 1:N) {
    U <- runif(1, 0, exp(a.max))
    V <- runif(1, 0, exp(b.max))
    rho <- V/U^r
    while (log(U) > betaLog(rho)) {
      U <- runif(1, 0, exp(a.max))
      V <- runif(1, 0, exp(b.max))
      rho <- V/U^r
    }
    b.val[j] <- rho
    a.val[j] <- LearnBayes::rigamma(1, n/2 + a2, sum(x/rho + rho/x - 2)/2 + b2)
  }
  #cred.a <- emp.hpd(sqrt(a.val), conf = cred.level)
  #cred.b <- emp.hpd(b.val, conf = cred.level)
  alpha <- sqrt(a.val) #c(median(sqrt(a.val)), sd(sqrt(a.val)), cred.a)
  beta <-  b.val #c(median(b.val), sd(b.val), cred.b)
  output <- cbind(alpha, beta)
  #colnames(output) <- c("Median", "SD", "Lower", "Upper")
  return(output)
}

#' Bayesian sample size in a decision-theoretic approach for the Birbaum-Saunders/inverse-gamma model.
#'
#'@description A function
#'
#'@usage bss.dt.bs(lf, a1, b1, a2, b2, c, rho = NULL, gam = NULL,
#'                 nmax = 1E2, nlag = 1E1, nrep = 1E2, lrep = 1E2,
#'                 npost = 1E2, plot = FALSE, ...)
#'
#' @param lf 1 or 2, representing the loss function used.
#' @param a1 Hyperparameter of the prior distribution for beta.
#' @param b1 Hyperparameter of the prior distribution for beta.
#' @param a2 Hyperparameter of the prior distribution for alpha^2.
#' @param b2 Hyperparameter of the prior distribution for alpha^2.
#' @param c A positive real number representing the cost of colect one aliquot.
#' @param rho A number in (0, 1). The probability of the credible interval is $1-rho$. Only
#' for lost function 1.
#' @param gam A positive real number connected with the credible interval when using lost
#' function 2.
#' @param nmax A positive integer representing the maximum number for compute the Bayes risk.
#' Default is 100.
#' @param nlag A positive integer representing the lag in the n's used to compute the Bayes risk. Default is 10.
#' @param nrep A positive integer representing the number of samples taken for each $n$.
#' @param lrep A positive integer representing the number of samples taken for $S_n$. Default is 100.
#' @param npost A positive integer representing the number of values to draw from the posterior distribution of the mean. Default is 100.
#' @param plot Boolean. If TRUE (default) it plot the estimated Bayes risks and the fitted curve.
#' @param ... Currently ignored.
#'
#' @return An integer representing the sample size.
#' @export
bss.dt.bs <- function(lf, a1, b1, a2, b2, c, rho = NULL, gam = NULL,
                      nmax = 1E2, nlag = 1E1, nrep = 1E2, lrep = 1E2, npost = 1E2, plot = FALSE, ...) {
  cl <- match.call()
  ns <- rep(seq(3, nmax, by = nlag), each = nrep)
  if (lf == 1) { # quadratic loss
    risk <- sapply(ns, function(n) {
      loss <- sapply(seq_len(lrep), function(j) {
        alpha2 <- LearnBayes::rigamma(n = n, a = a2, b = b2)
        alpha <- sqrt(alpha2)
        beta <- LearnBayes::rigamma(n = n, a = a1, b = b1)
        x <- rbs(n = 1, alpha = alpha, beta = beta)
        post.xn <- rpost.bs(N = npost, x = x, a1 = a1, b1 = b1, a2 = a2,
                            b2 = b2, r = 3) # mudar r depois
        mu.post <- post.xn[, 2]*(1 + post.xn[, 1]^2/2)
        out.loss <- stats::var(mu.post) + c*n
        return(out.loss)
      })
      out.risk <- mean(loss)
      return(out.risk)
    })
  }
  if (lf == 2) { # absolute loss
    risk <- sapply(ns, function(n) {
      loss <- sapply(seq_len(lrep), function(j) {
        alpha2 <- LearnBayes::rigamma(n = n, a = a2, b = b2)
        alpha <- sqrt(alpha2)
        beta <- LearnBayes::rigamma(n = n, a = a1, b = b1)
        x <- rbs(n = 1, alpha = alpha, beta = beta)
        post.xn <- rpost.bs(N = npost, x = x, a1 = a1, b1 = b1, a2 = a2,
                            b2 = b2, r = 3) # mudar r depois
        mu.post <- post.xn[, 2]*(1 + post.xn[, 1]^2/2)
        med.post <- median(mu.post)
        out.loss <- mean(abs(mu.post - med.post)) + c*n
        return(out.loss)
      })
      out.risk <- mean(loss)
      return(out.risk)
    })
  }
  if (lf == 3) { # loss function for interval inference depending on rho
    risk <- sapply(ns, function(n) {
      loss <- sapply(seq_len(lrep), function(j) {
        alpha2 <- LearnBayes::rigamma(n = n, a = a2, b = b2)
        alpha <- sqrt(alpha2)
        beta <- LearnBayes::rigamma(n = n, a = a1, b = b1)
        x <- rbs(n = 1, alpha = alpha, beta = beta)
        post.xn <- rpost.bs(N = npost, x = x, a1 = a1, b1 = b1, a2 = a2,
                            b2 = b2, r = 3) # mudar r depois
        mu.post <- post.xn[, 2]*(1 + post.xn[, 1]^2/2)
        qs <- stats::quantile(mu.post, probs = c(rho/2, 1 - rho/2))
        out.loss <- sum(mu.post[which(mu.post > qs[2])])/npost - sum(mu.post[which(mu.post < qs[1])])/npost + c*n
        return(out.loss)
      })
      out.risk <- mean(loss)
      return(out.risk)
    })
  }
  if (lf == 4) { # loss function for interval inference depending on gamma
    risk <- sapply(ns, function(n) {
      loss <- sapply(seq_len(lrep), function(j) {
        alpha2 <- LearnBayes::rigamma(n = n, a = a2, b = b2)
        alpha <- sqrt(alpha2)
        beta <- LearnBayes::rigamma(n = n, a = a1, b = b1)
        x <- rbs(n = 1, alpha = alpha, beta = beta)
        post.xn <- rpost.bs(N = npost, x = x, a1 = a1, b1 = b1, a2 = a2,
                            b2 = b2, r = 3) # mudar r depois
        mu.post <- post.xn[, 2]*(1 + post.xn[, 1]^2/2)
        out.loss <- 2*sqrt(gam*stats::var(mu.post)) + c*n
        return(out.loss)
      })
      out.risk <- mean(loss)
      return(out.risk)
    })
  }
  Y <- log(risk - c*ns)
  fit <- stats::lm(Y ~ I(log(ns + 1)))
  E <- as.numeric(exp(fit$coef[1]))
  G <- as.numeric(-fit$coef[2])
  nmin <- ceiling((E*G/c)^(1/(G + 1))-1)
  if (plot == TRUE) {
    plot(ns, risk, xlim = c(0, nmax), xlab = "n", ylab = "TC(n)")
    curve <- function(x) {c*x + E/(1 + x)^G}
    plot(function(x) curve(x), 0, nmax, col = "blue", add = TRUE)
    graphics::abline(v = nmin, col = "red")
  }
  # Output
  cat("\nCall:\n")
  print(cl)
  cat("\nSample size:\n")
  cat("n  = ", nmin, "\n")
}