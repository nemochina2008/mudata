
#' Combine mudata objects
#' 
#' This implmentation of \link{rbind} combines component tables using \link[dplyr]{bind_rows}
#' and \link[dplyr]{distinct}. When combined object use different datasets, or when subsets of
#' the same object are recombined, this function works well. When this is not the case, it
#' may be necessary to modify the tables such that when they are passed to \link[dplyr]{bind_rows}
#' and \link[dplyr]{distinct}, no duplicate information exists. This should be picked up by
#' \link{validate_mudata}.
#'
#' @param ... \link{mudata} objects to combine
#' @param validate Flag to validate the final object using \link{validate_mudata}.
#'
#' @return A mudata object
#' @export
#' 
#' @examples
#' rbind(
#'   kentvillegreenwood %>% 
#'     select_params(maxtemp) %>% 
#'     select_locations(starts_with("KENT")),
#'   kentvillegreenwood %>% 
#'     select_params(mintemp) %>% 
#'     select_locations(starts_with("GREEN"))
#' )
#'
rbind.mudata <- function(..., validate = TRUE) {
  mudatas <- list(...)
  x_columns <- unname(unique(unlist(lapply(mudatas, attr, "x_columns"))))
  mudata(
    data = do.call(dplyr::bind_rows, lapply(mudatas, function(m) m$data)),
    locations = dplyr::distinct(do.call(dplyr::bind_rows, lapply(mudatas, function(m) m$locations))),
    params = dplyr::distinct(do.call(dplyr::bind_rows, lapply(mudatas, function(m) m$params))),
    datasets = dplyr::distinct(do.call(dplyr::bind_rows, lapply(mudatas, function(m) m$datasets))),
    columns = dplyr::distinct(do.call(dplyr::bind_rows, lapply(mudatas, function(m) m$columns))),
    x_columns = x_columns, validate = validate
  )
}

#' Subset a MuData object
#' 
#' This object uses standard evalutation to subset a \link{mudata} object using
#' character vectors of datasets, params, and locations. The result is subsetted such
#' that all rows in the data table are documented in the other tables (provided)
#' they were to begin with. It is preferred to use \link{select_locations},
#' \link{select_params}, and \link{select_datasets} to subset a mudata object,
#' or \link{filter_data}, \link{filter_locations}, \link{filter_params}, 
#' and \link{filter_datasets} to subset by row while maintaining internal
#' consistency.
#'
#' @param x The object to subset
#' @param datasets Vector of datasets to include
#' @param params  Vector of parameters to include
#' @param locations Vector of locations to include
#' @param ... Used to \link[dplyr]{filter} the data table
#' 
#' @seealso 
#' \link{select_locations}, \link{select_params}, \link{select_datasets}, \link{filter_data}, 
#' \link{filter_locations}, \link{filter_params}, and \link{filter_datasets}
#'
#' @return A subsetted mudata object
#' @export
#' 
#' @examples 
#' subset(kentvillegreenwood, params = c("mintemp", "maxtemp"))
#'
subset.mudata <- function(x, ..., datasets = NULL, params = NULL, 
                          locations = NULL) {
  # enquos ...
  filter_args <- rlang::quos(...)
  
  # filter data
  new_x <- filter_data(x, rlang::UQS(filter_args))
  if(!is.null(datasets)) {
    new_x <- filter_data(new_x, .data$dataset %in% datasets)
  }
  if(!is.null(locations)) {
    new_x <- filter_data(new_x, .data$location %in% locations)
  }
  if(!is.null(params)) {
    new_x <- filter_data(new_x, .data$param %in% params)
  }
  
  # return filtered object
  new_x
}

#' Subset a mudata object by identifier
#' 
#' These functions use dplyr-like selection syntax to quickly subset a mudata
#' object by param, location, or dataset. Params, locations, an datasets can also
#' be renamed using keyword arguments, identical to dplyr selection syntax.
#'
#' @param .data A mudata object
#' @param ... Quoted names, bare names, or helpers like \link[dplyr]{starts_with},
#'   \link[dplyr]{contains}, \link[dplyr]{ends_with}, \link[dplyr]{one_of},
#'   or \link[dplyr]{matches}.
#' @param .factor If TRUE, the new object will keep the order specified by converting
#'   columns to factors. This may be useful for specifying order when using
#'   \link{autoplot.mudata}.
#'
#' @seealso
#' \link[dplyr]{select}, \link{rename_locations}, \link{distinct_locations}, 
#' \link{filter_locations}
#'
#' @rdname selecters
#' @return A subsetted mudata object.
#' @export
#'
#' @examples
#' # renaming can be handy when locations are verbosely named
#' ns_climate %>% 
#'   select_locations(sable_island = starts_with("SABLE"),
#'                    nappan = starts_with("NAPPAN"), 
#'                    baddeck = starts_with("BADDECK")) %>% 
#'   select_params(ends_with("temp"))
#'   
#' # can also use quoted values
#' long_lake %>%
#'   select_params("Pb", "As", "Cr")
#'
#' # can also use negative values to remove params/datasets/locations
#' long_lake %>%
#'   select_params(-Pb)
#'   
#' # to get around non-standard evaluation, use one_of()
#' my_params <- c("Pb", "As", "Cr")
#' long_lake %>%
#'   select_params(one_of(my_params))
#' 
select_datasets <- function(.data, ...) {
  UseMethod("select_datasets")
}
 
#' @rdname selecters
#' @export
select_datasets.default <- function(.data, ..., .factor = FALSE) {
  # quo-ify datasets
  datasets <- rlang::quos(...)
  # use tidyselect to get dataset names
  datasets <- tidyselect::vars_select(.tidyselect_vars(.data, "dataset"), rlang::UQS(datasets))
  new_datasets <- names(datasets)
  # use subset() to do the subsetting
  md_out <- filter_data(.data, .data$dataset %in% datasets)
  # rename datasets using rename_dataset
  if(any(new_datasets != datasets)) {
    renamer <- datasets[new_datasets != datasets]
    md_out <- rename_datasets_base(md_out, stats::setNames(names(renamer), renamer))
  }
  
  if(.factor) {
    md_out <- .factorize(md_out, "dataset", new_datasets)
  }
  
  md_out
}

#' @rdname selecters
#' @export
select_locations <- function(.data, ...) {
  UseMethod("select_locations")
}

#' @rdname selecters
#' @export
select_locations.default <- function(.data, ..., .factor = FALSE) {
  # quo-ify locations
  locations <- rlang::quos(...)
  # use tidyselect to get location names
  locations <- tidyselect::vars_select(.tidyselect_vars(.data, "location"), rlang::UQS(locations))
  new_locations <- names(locations)
  # use subset() to do the subsetting
  md_out <- filter_data(.data, .data$location %in% locations)
  # rename datasets using rename_locations_base
  if(any(new_locations != locations)) {
    renamer <- locations[new_locations != locations]
    md_out <- rename_locations_base(md_out, stats::setNames(names(renamer), renamer))
  } 
  
  if(.factor) {
    md_out <- .factorize(md_out, "location", new_locations)
  }
  
  md_out
}

#' @rdname selecters
#' @export
select_params <- function(.data, ...) {
  UseMethod("select_params")
}

#' @rdname selecters
#' @export
select_params <- function(.data, ..., .factor = FALSE) {
  # quo-ify params
  params <- rlang::quos(...)
  # use tidyselect to get location names
  params <- tidyselect::vars_select(.tidyselect_vars(.data, "param"), rlang::UQS(params))
  new_params <- names(params)
  # use subset() to do the subsetting
  md_out <- filter_data(.data, .data$param %in% params)
  # rename datasets using rename_params_base
  if(any(new_params != params)) {
    renamer <- params[new_params != params]
    md_out <- rename_params_base(md_out, stats::setNames(names(renamer), renamer))
  }
  
  if(.factor) {
    md_out <- .factorize(md_out, "param", new_params)
  }
  
  md_out
}


#' Subset a mudata object by complex expression
#' 
#' These methods allow more complex selection criteria than \link{select_datasets} and
#' family, which only use the identifier values. These methods first subset
#' the required table using the provided expression, then subset other tables
#' to ensure internal consistency.
#'
#' @param .data A \link{mudata} object
#' @param ... Objects passed to \link[dplyr]{filter} on the appropriate table
#' 
#' @seealso
#' \link[dplyr]{filter}, \link{select_locations}
#'
#' @rdname filterers
#' @return A subsetted mudata object
#' @export
#'
#' @examples
#' # select only locations with a latitude above 45
#' ns_climate %>%
#'   filter_locations(latitude > 45)
#'
#' # select only params measured in mm
#' ns_climate %>%
#'   filter_params(unit == "mm")
#'
#' # select only june temperature from ns_climate
#' library(lubridate)
#' ns_climate %>%
#'   filter_data(month(date) == 6)
#' 
filter_datasets <- function(.data, ...) {
  UseMethod("filter_datasets")
}

#' @rdname filterers
#' @export
filter_datasets.default <- function(.data, ...) {
  filter_args <- rlang::quos(...)
  if(length(filter_args) == 0) return(.data)
  
  datasets <- .data$datasets %>%
    dplyr::filter(rlang::UQS(filter_args)) %>%
    dplyr::distinct("dataset") %>%
    dplyr::collect() %>%
    dplyr::pull("dataset")
  filter_data(.data, .data$dataset %in% datasets)
}

#' @rdname filterers
#' @export
filter_data <- function(.data, ...) {
  UseMethod("filter_data")
}

#' @rdname filterers
#' @export
filter_data.default <- function(.data, ...) {
  filter_args <- rlang::quos(...)
  if(length(filter_args) == 0) return(.data)
  
  # lazily filter data
  dta <- dplyr::filter(.data$data, rlang::UQS(filter_args))
  
  # redefine params, locations, datasets to reflect subsetted data
  params <- dplyr::distinct(dta, "param")$param
  locations <- dplyr::distinct(dta, "location")$location
  datasets <- dplyr::distinct(dta, "dataset")$dataset
  
  pm <- dplyr::filter(.data$params, .data$param %in% params)
  lc <- dplyr::filter(.data$locations, .data$location %in% locations)
  cl <- dplyr::filter(.data$columns, .data$dataset %in% datasets)
  ds <- dplyr::filter(.data$datasets, .data$dataset %in% datasets)
  
  # keep class of original
  new_mudata(list(data=dta, locations=lc, params=pm, datasets=ds, 
                  columns=cl), x_columns = x_columns(.data))
}

#' @rdname filterers
#' @export
filter_locations <- function(.data, ...) {
  UseMethod("filter_locations")
}

#' @rdname filterers
#' @export
filter_locations.default <- function(.data, ...) {
  filter_args <- rlang::quos(...)
  if(length(filter_args) == 0) return(.data)
  
  locations <- .data$locations %>%
    dplyr::filter(rlang::UQS(filter_args)) %>%
    dplyr::mutate(.id = paste(.data$dataset, .data$location, sep = "/////")) %>%
    dplyr::pull(".id")
  filter_data(.data, paste(.data$dataset, .data$location, sep = "/////") %in% locations)
}

#' @rdname filterers
#' @export
filter_params <- function(.data, ...) {
  UseMethod("filter_params")
}

#' @rdname filterers
#' @export
filter_params <- function(.data, ...) {
  filter_args <- rlang::quos(...)
  if(length(filter_args) == 0) return(.data)
  
  params <- .data$params %>%
    dplyr::filter(rlang::UQS(filter_args)) %>%
    dplyr::mutate(.id = paste(.data$dataset, .data$param, sep = "/////")) %>%
    dplyr::pull(".id")
  filter_data(.data, paste(.data$dataset, .data$param, sep = "/////") %in% params)
}

.tidyselect_vars <- function(x, type) {
  singular <- type
  plural <- paste0(type, "s")
  vars <- as.character(.distinct_vector(x[[plural]], singular))
  attr(vars, "type") <- c(singular, plural)
  vars
}

.factorize <- function(md, column, levels) {
  for(tbl in src_tbls(md)) {
    if(column %in% colnames(md[[tbl]])) {
      md[[tbl]][[column]] <- factor(md[[tbl]][[column]], levels = levels)
    }
  }
  md
}

