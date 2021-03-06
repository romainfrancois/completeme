#' @importFrom glue glue
NULL

the <- new.env(parent = emptyenv())
the$completions <- list()

#' @importFrom glue collapse single_quote
vals <- function(x) {
  collapse(single_quote(x), sep = ", ", last = " and ")
}

#' @importFrom glue glue
#' @importFrom rlang abort
#' @importFrom utils modifyList
halt <- function(msg, type = NULL) {
  abort(do.call(glue, c(msg, .envir = parent.frame())), type = type)
}

#' Register completion functions
#'
#' Completion functions should take one parameter `env`, the completion
#' environment, see `?rc.settings` for details of this environment. They should
#' set the `comps` and `fileName` fields of the completion and return `TRUE` if
#' no further completions should be attempted. They should return `FALSE` if
#' there are no completions for the current context.
#'
#' If all registered completions return `FALSE` for a given context, than R's
#' standard completions are used.
#' @param ... One or more completion functions specified as named parameters.
#' @export
register_completion <- function(...) {
  funs <- list(...)

  nms <- names(funs)
  if (is.null(nms) || any(nms == "" | is.na(nms))) {
    wch <- if (is.null(nms)) 1 else which(nms == "" | is.na(nms))
    halt("All arguments must be named. Unnamed arguments at position {vals(wch)}.", "argument_error")
  }

  old <- the$completions
  the$completions <- modifyList(the$completions, funs)

  invisible(old)
}

#' @importFrom utils rc.options
completeme <- function(env) {
  for (fun in the$completions) {
    if (isTRUE(fun(env))) {
      return()
    }
  }
  # Fall back to using the default completer
  on.exit(rc.options(custom.completer = completeme))
  rc.options(custom.completer = NULL)
  complete_token()
}

#' @importFrom rlang warn
#' @importFrom utils rc.getOption rc.options
.onLoad <- function(lib, pkg) {
  if (!is.null(default <- rc.getOption("custom.completer"))) {
    if (!isTRUE(all.equal(default, completeme))) {
      warn("Found default custom.completer, registering as 'default'")
      #register_completion(default = default)
    }
  }
  rc.options(custom.completer = completeme)
}

#' Completion helpers
#'
#' @param env The completion environment, see `?rc.status()` for details.
#' @name helpers
NULL

#' @describeIn helpers Returns the current function call, or `""` if
#' not within a call.
#' @export
current_function <- function(env) {
  fun <- get("inFunction", asNamespace("utils"))
  res <- fun(line = env[["linebuffer"]], cursor = env[["start"]])
  if (length(res) == 0) {
    return("")
  }
  res
}

#' @describeIn helpers Returns `TRUE` if within single or double quotes.
#' @importFrom utils head
#' @export
# Adapted from utils:::isInsideQuotes
inside_quotes <- function(env) {
  (env[["start"]] > 0 && {
    linebuffer <- env[["linebuffer"]]
    lbss <- head(unlist(strsplit(linebuffer, "")),
      env[["end"]])
    ((sum(lbss == "'") %% 2 == 1) || (sum(lbss == "\"") %% 2 == 1))
  })
}

complete_token <- get(".completeToken", asNamespace("utils"))
