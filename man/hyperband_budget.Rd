% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helper.R
\name{hyperband_budget}
\alias{hyperband_budget}
\title{Hyperband Budget}
\usage{
hyperband_budget(r_min, r_max, eta, integer_budget = FALSE)
}
\arguments{
\item{r_min}{(\code{numeric(1)})\cr
Lower bound of budget parameter.}

\item{r_max}{(\code{numeric(1)})\cr
Upper bound of budget parameter.}

\item{eta}{(\code{numeric(1)})\cr
Fraction parameter of the successive halving algorithm: With every stage the
configuration budget is increased by a factor of \code{eta} and only the best
\code{1/eta} points are used for the next stage. Non-integer values are supported,
but \code{eta} is not allowed to be less or equal 1.}

\item{integer_budget}{(\code{logical(1)})\cr
Determines if budget is an integer.}
}
\value{
\code{integer(1)}
}
\description{
Calculates the total budget used by hyperband.
}
