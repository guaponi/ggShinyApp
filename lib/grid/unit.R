#functions from the now deprecated 'grid' package

recycle.data <- function(data, data.per, max.n) {
  # VERY IMPORTANT:  Even if there is only one data specified
  # and/or only one data needed, we want this to be a LIST of
  # data values so that a single data and several data can be
  # handled equivalently
  # The test for whether it is only a single value currently
  # consists of a check for mode="character" (i.e., a single
  # string) or mode="expression" (i.e., a single expression)
  # or class="grob" (i.e., a single grob)
  if (is.character(data) || is.expression(data)) 
    data <- list(data)
  if (data.per)
    n <- max.n
  else
    n <- length(data)
  original <- data
  index <- 1
  while (length(data) < n) {
    data <- c(data, list(original[[(index - 1) %% length(original) + 1]]))
    index <- index + 1
  }
  data
}

# Create an object of class "unit"
# Simple units are of the form `unit(1, "cm")' or `unit(1:3, "cm")' or
# `unit(c(1,3,6), c("cm", "inch", "npc"))'
# More complicated units are of the form `unit(1, "string", "a string")'
# or `unit(1, "grob", a.grob)'
unit <- function(x, units, data=NULL) {
  if (!is.numeric(x))
    stop("x must be numeric")
  if (length(x) == 0 || length(units) == 0)
    stop("x and units must have length > 0")
  valid.unit(x, units, recycle.data(data, FALSE, length(x)))
}

valid.unit <- function(x, units, data) {
  valid.units <- valid.units(units)
  # data <- valid.data(rep(units, length.out=length(x)), data)
  attr(x, "unit") <- units
  attr(x, "valid.unit") <- valid.units
  attr(x, "data") <- data
  class(x) <- "unit"
  x
}

convertNative <- function(unit, dimension="x", type="location") {
  what <- match(dimension, c("x", "y")) - 1 +
    2*(match(type, c("location", "dimension")) - 1)
  if (!is.unit(unit))
    stop("`unit' argument must be a unit object")
  if (is.na(what))
    stop("Invalid dimension or type")
  grid.Call("L_convertToNative", unit, as.integer(what))
}

# NOTE: the order of the strings in these conversion functions must
# match the order of the enums in ../src/grid.h
.grid.unit.list <- c("npc", "cm", "inches", "lines",
                     "native", "null", "snpc", "mm",
                     "points", "picas", "bigpts",
                     "dida", "cicero", "scaledpts",
                     "strwidth", "strheight",
                     "vplayoutwidth", "vplayoutheight", "char",
                     "grobwidth", "grobheight",
                     "mylines", "mychar", "mystrwidth", "mystrheight")

# Make sure that and "str*" and "grob*" units have data
# valid.data <- function(units, data) {
#   n <- length(units)
#   str.units <- (units == "strwidth" | units == "mystrwidth")
#   if (any(str.units != 0))
#     for (i in (1:n)[str.units])
#       if (!(length(data) >= i &&
#             (is.character(data[[i]]) || is.expression(data[[i]]))))
#         stop("No string supplied for `strwidth' unit")
#   str.units <- (units == "strheight" | units == "mystrheight")
#   if (any(str.units != 0))
#     for (i in (1:n)[str.units])
#       if (!(length(data) >= i &&
#             (is.character(data[[i]]) || is.expression(data[[i]]))))
#         stop("No string supplied for `strheight' unit")
#   # Make sure that a grob has been specified
#   grob.units <- units == "grobwidth"
#   if (any(grob.units != 0))
#     for (i in (1:n)[grob.units]) {
#       if (!(length(data) >= i && is.grob(data[[i]])))
#         stop("No grob supplied for `grobwidth' unit")
#     }
#   grob.units <- units == "grobheight"
#   if (any(grob.units != 0))
#     for (i in (1:n)[grob.units]) {
#       if (!(length(data) >= i && is.grob(data[[i]])))
#         stop("No grob supplied for `grobheight' unit")
#     }
#   data
# }

valid.units <- function(units) {
  .Call("validUnits", units, PACKAGE="grid")
}

as.character.unit <- function(unit) {
  class(unit) <- NULL
  paste(unit, attr(unit, "unit"), sep="")
}

#########################
# UNIT ARITHMETIC STUFF
#########################

unit.arithmetic <- function(func.name, arg1, arg2=NULL) {
  ua <- list(fname=func.name, arg1=arg1, arg2=arg2)
  class(ua) <- c("unit.arithmetic", "unit")
  ua
}

Ops.unit <- function(x, y) {
  ok <- switch(.Generic, "+"=TRUE, "-"=TRUE, "*"=TRUE, FALSE)
  if (!ok)
    stop(paste("Operator", .Generic, "not meaningful for units"))
  if (.Generic=="*")
    # can only multiply a unit by a scalar
    if (nchar(.Method[1])) {
      if (nchar(.Method[2]))
        stop("Only one operand may be a unit")
      else if (is.numeric(y))
        # NOTE that we always put the scalar first
        unit.arithmetic(.Generic, y, x)
      else
        stop("Non-unit operand must be numeric")
    } else {
      if (is.numeric(x))
        unit.arithmetic(.Generic, x, y)
      else
        stop("Non-unit operand must be numeric")
    }
  else
    # Check that both arguments are units
    if (nchar(.Method[1]) && nchar(.Method[2]))
      unit.arithmetic(.Generic, x, y)
    else
      stop("Both operands must be units") 
}    

Summary.unit <- function(..., na.rm=FALSE) {
  # NOTE that this call to unit.c makes sure that arg1 is
  # a single unit object 
  x <- unit.c(...)
  ok <- switch(.Generic, "max"=TRUE, "min"=TRUE, "sum"=TRUE, FALSE)
  if (!ok)
    stop(paste("Summary function", .Generic, "not meaningful for units"))
  unit.arithmetic(.Generic, x)
}

is.unit.arithmetic <- function(x) {
  inherits(x, "unit.arithmetic")
}

as.character.unit.arithmetic <- function(ua) {
  # bit too customised for my liking, but whatever ...
  # NOTE that paste coerces arguments to mode character hence
  # this will recurse.
  fname <- ua$fname
  if (fname == "+" || fname == "-" || fname == "*")
    paste(ua$arg1, fname, ua$arg2, sep="")
  else
    paste(fname, "(", paste(ua$arg1, collapse=", "), ")", sep="")
}

unit.pmax <- function(...) {

  select.i <- function(unit, i) {
    "["(unit, i, top=FALSE)
  }

  x <- list(...)
  numargs <- length(x)
  if (numargs == 0)
    stop("Zero arguments where at least one expected")
  # how long will the result be?
  maxlength <- 0
  for (i in 1:numargs)
    if (unit.length(x[[i]]) > maxlength)
      maxlength <- unit.length(x[[i]])
  # maxlength guaranteed >= 1
  result <- max(unit.list.from.list(lapply(x, select.i, 1)))
  for (i in 2:maxlength)
    result <- unit.c(result, max(unit.list.from.list(lapply(x, select.i, i))))
  result
}

unit.pmin <- function(...) {

  select.i <- function(unit, i) {
    "["(unit, i, top=FALSE)
  }

  x <- list(...)
  numargs <- length(x)
  if (numargs == 0)
    stop("Zero arguments where at least one expected")
  # how long will the result be?
  maxlength <- 0
  for (i in 1:numargs)
    if (unit.length(x[[i]]) > maxlength)
      maxlength <- unit.length(x[[i]])
  # maxlength guaranteed >= 1
  result <- min(unit.list.from.list(lapply(x, select.i, 1)))
  for (i in 2:maxlength)
    result <- unit.c(result, min(unit.list.from.list(lapply(x, select.i, i))))
  result  
}

#########################
# UNIT LISTS
# The idea with these is to allow arbitrary combinations
# of unit objects and unit arithmetic objects
#########################

# create a unit list from a unit, unit.arithmetic, or unit.list object
unit.list <- function(unit) {
  if (is.unit.list(unit))
    unit
  else {
    l <- unit.length(unit)
    result <- list() 
    for (i in 1:l)
      result[[i]] <- unit[i]
    class(result) <- c("unit.list", "unit")
    result
  }
}

is.unit.list <- function(x) {
  inherits(x, "unit.list")
}
  
as.character.unit.list <- function(ul) {
  l <- unit.length(ul)
  result <- rep("", l)
  for (i in 1:unit.length(ul))
    result[i] <- as.character(ul[[i]])
  result
}

#########################
# These work on any sort of unit object
#########################

is.unit <- function(unit) {
  inherits(unit, "unit")
}

print.unit <- function(x, ...) {
  print(as.character(x), quote=FALSE)
}

#########################
# Unit subsetting
#########################

# The idea of the "top" argument is to allow the function to
# know if it has been called from the command-line or from
# a previous (recursive) call to "[.unit" or "[.unit.arithmetic"
# this allows recycling beyond the end of the unit object
# except at the top level

# NOTE that "unit" and "data" attributes will be recycled
"[.unit" <- function(x, index, top=TRUE, ...) {
  this.length <- length(x)
  if (top && index > this.length)
    stop("Index out of bounds (unit subsetting)")
  cl <- class(x);
  units <- attr(x, "unit")
  valid.units <- attr(x, "valid.unit")
  data <- attr(x, "data")
  class(x) <- NULL;
  # The line below may seem slightly odd, but it should only be
  # used to recycle values when this method is called to
  # subset an argument in a unit.arithmetic object
  x <- x[(index - 1) %% this.length + 1]
  attr(x, "unit") <- units[(index - 1) %% length(units) + 1]
  attr(x, "valid.unit") <- valid.units[(index - 1) %% length(valid.units) + 1]
  data.list <- data[(index - 1) %% length(data) + 1]
  attr(x, "data") <- data.list
  class(x) <- cl
  x
}

# NOTE that units will be recycled to the length of the largest
# of the arguments
"[.unit.arithmetic" <- function(x, index, top=TRUE, ...) {
  this.length <- unit.arithmetic.length(x)
  if (top && index > this.length)
    stop("Index out of bounds (unit arithmetic subsetting)")
  switch(x$fname,
         "+"="["(x$arg1, (index - 1) %% this.length + 1, top=FALSE) +
             "["(x$arg2, (index - 1) %% this.length + 1, top=FALSE),
         "-"="["(x$arg1, (index - 1) %% this.length + 1, top=FALSE) -
             "["(x$arg2, (index - 1) %% this.length + 1, top=FALSE),
         "*"=x$arg1 *
             "["(x$arg2, (index - 1) %% this.length + 1, top=FALSE),
         "min"=x,
         "max"=x,
         "sum"=x)
}

"[.unit.list" <- function(x, index, top=TRUE, ...) {
  this.length <- unit.list.length(x)
  if (top && index > this.length)
    stop("Index out of bounds (unit list subsetting)")
  cl <- class(x)
  result <- unclass(x)[(index - 1) %% this.length + 1]
  class(result) <- cl
  result
}

# Write "[<-.unit" methods too ?? 

#########################
# "c"ombining unit objects
#########################

# NOTE that I have not written methods for c()
# because method dispatch occurs on the first argument to
# "c" so c(unit(...), ...) would come here, but c(whatever, unit(...), ...)
# would go who-knows-where.
# A particularly nasty example is:  c(1, unit(1, "npc")) which will
# produce the same result as c(1, 1)
# Same problem for trying to control c(<unit>, <unit.arithmetic>)
# versus c(<unit.arithmetic>, <unit>), etc ...

# If any arguments are unit.arithmetic or unit.list, then the result will be
# unit.list
unit.c <- function(...) {
  x <- list(...)
  ual <- FALSE
  for (i in 1:length(x))
    if (inherits(x[[i]], "unit.list") ||
        inherits(x[[i]], "unit.arithmetic"))
      ual <- TRUE
  if (ual)
    unit.list.from.list(x)
  else {
    values <- NULL
    units <- NULL
    data <- NULL
    for (i in 1:length(x))
      if (is.unit(x[[i]])) {
        values <- c(values, x[[i]])
        units <- c(units, rep(attr(x[[i]], "unit"), length.out=length(x[[i]])))
        data <- c(data, recycle.data(attr(x[[i]], "data"), TRUE,
                                     length(x[[i]])))
      }
      else 
        stop("It is invalid to combine unit objects with other types")
    unit(values, units, data=data)
  }
}

unit.list.from.list <- function(x) {
  if (length(x) == 1)
    unit.list(x[[1]])
  else {
    result <- c(unit.list(x[[1]]), unit.list.from.list(x[2:length(x)]))
    class(result) <- c("unit.list", "unit")
    result
  }
}

# OLD unit.list.from.list <-
function(x) {
  result <- unit.list(x[[1]])
  i <- 2
  while (i < length(x) + 1) {
    result <- c(result, unit.list(x[[i]]))
    i <- i + 1
  }
  class(result) <- c("unit.list", "unit")
  result 
}

#########################
# rep'ing unit objects
#########################

# NOTE that rep() is not a generic -- it does have different "methods"
# for some different data types, but this is ALL handled internally
# in seq.c

unit.arithmetic.rep <- function(x, times) {
  switch(x$fname,
         "+"=unit.rep(x$arg1, times) + unit.rep(x$arg2, times),
         "-"=unit.rep(x$arg1, times) - unit.rep(x$arg2, times),
         "*"=x$arg1 * unit.rep(x$arg2, times),
         "min"=unit.list.rep(unit.list(x), times),
         "max"=unit.list.rep(unit.list(x), times),
         "sum"=unit.list.rep(unit.list(x), times))
}

unit.list.rep <- function(x, times) {
  # Make use of the subsetting code to replicate the unit list
  # top=FALSE allows the subsetting to go beyond the original length
  "["(x, 1:(unit.length(x)*times), top=FALSE)
}

unit.rep <- function (x, times, length.out) 
{
  if (unit.length(x) == 0) 
    return(x)
  if (missing(times)) 
    times <- ceiling(length.out/length(x))
  
  if (is.unit.list(x))
    unit <- unit.list.rep(x, times)
  else if (is.unit.arithmetic(x))
    unit <- unit.arithmetic.rep(x, times)
  else {
    values <- rep(x, times)
    # Do I need to replicate the "unit"s?
    unit <- attr(x, "unit")
    # If there are any data then they must be explicitly replicated
    # because the list of data must be the same length as the
    # vector of values
    data <- recycle.data(attr(x, "data"), TRUE, length(values))
    unit <- unit(values, unit, data=data)
  }
  if (!missing(length.out)) 
    return(unit[if (length.out > 0) 1:length.out else integer(0)])
  unit
}

#########################
# Length of unit objects
#########################

unit.list.length <- function(ul) {
  length(ul)
}

# unit.length is designed to call this when appropriate
# so that this need never be called by the user
unit.arithmetic.length <- function(ua) {
  switch(ua$fname,
         "+"=max(unit.length(ua$arg1), unit.length(ua$arg2)),
         "-"=max(unit.length(ua$arg1), unit.length(ua$arg2)),
         "*"=max(length(ua$arg1), unit.length(ua$arg2)),
         "min"=1,
         "max"=1,
         "sum"=1)
}

# FIXME: I am doing my own dispatching here;  should be generic function
unit.length <- function(unit) {
  if (is.unit.list(unit))
    unit.list.length(unit)
  else if (is.unit.arithmetic(unit))
    unit.arithmetic.length(unit)
  else
    length(unit)
}

#########################
# Function to decide which values in a unit are "absolute" (do not depend
# on parent's drawing context or size)
#########################

# Only deals with unit of unit.length() 1
absolute <- function(unit) {
  !is.na(match(attr(unit, "unit"),
               c("cm", "inches", "lines", "null",
                 "mm", "points", "picas", "bigpts",
                 "dida", "cicero", "scaledpts",
                 "strwidth", "strheight", "char",
                 "mylines", "mychar", "mystrwidth", "mystrheight")))
}

absolute.units.list <- function(ul) {
  cl <- class(ul)
  abs.ul <- lapply(ul, absolute.units)
  class(abs.ul) <- cl
  abs.ul
}
                                  
absolute.units.arithmetic <- function(ua) {
  switch(ua$fname,
         "+"=unit.arithmetic("+", absolute.units(ua$arg1),
           absolute.units(ua$arg2)),
         "-"=unit.arithmetic("-", absolute.units(ua$arg1),
           absolute.units(ua$arg2)),
         "*"=unit.arithmetic("*", ua$arg1, absolute.units(ua$arg2)),
         "min"=unit.arithmetic("min", absolute.units(ua$arg1)),
         "max"=unit.arithmetic("max", absolute.units(ua$arg1)),
         "sum"=unit.arithmetic("sum", absolute.units(ua$arg1)))
}

absolute.units <- function(unit) {
  if (is.unit.list(unit))
    absolute.units.list(unit)
  else if (is.unit.arithmetic(unit))
    absolute.units.arithmetic(unit)
  else {
    n <- unit.length(unit)
    if (absolute(unit[1]))
      abs.unit <- unit[1]
    else
      abs.unit <- unit(1, "null")
    if (n == 1)
      new.unit <- abs.unit
    else
      new.unit <- unit.c(abs.unit, absolute.units(unit[2:n]))
    new.unit
  }
}
                 
