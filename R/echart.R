#' Create an ECharts widget
#'
#' Create an HTML widget for ECharts that can be rendered in the R console, R
#' Markdown documents, or Shiny apps. You can add more components to this widget
#' and customize options later. \code{eChart()} is an alias of \code{echart()}.
#' @param data a data object (usually a data frame or a list)
#' @rdname eChart
#' @export
#' @examples library(recharts)
#' echart(iris, ~ Sepal.Length, ~ Sepal.Width)
#' echart(iris, ~ Sepal.Length, ~ Sepal.Width, series = ~ Species)
echart = function(data, ...) {
    UseMethod('echart')
}

#' @export
#' @rdname eChart
echart.list = function(data, width = NULL, height = NULL, ...) {
    htmlwidgets::createWidget(
        'echarts', data, width = width, height = height, package = 'recharts'
    )
}

#' @param x the x variable
#' @param y the y variable
#' @export
#' @rdname eChart
echart.data.frame = function(
    data = NULL, x = NULL, y = NULL, series = NULL, type = 'auto',
    width = NULL, height = NULL, ...
) {

    xlab = autoArgLabel(x, deparse(substitute(x)))
    ylab = autoArgLabel(y, deparse(substitute(y)))

    x = evalFormula(x, data)
    y = evalFormula(y, data)
    if (type == 'auto') type = determineType(x, y)
    if (type == 'bar') {
        x = as.factor(x)
        if (is.null(y)) ylab = 'Frequency'
    }

    series = evalFormula(series, data)
    data_fun = getFromNamespace(paste0('data_', type), 'recharts')

    params = structure(list(
        series = data_fun(x, y, series),
        xAxis = list(), yAxis = list()
    ), meta = list(
        x = x, y = y
    ))

    if (!is.null(series)) {
        params$legend = list(data = levels(as.factor(series)))
    }

    chart = htmlwidgets::createWidget(
        'echarts', params, width = width, height = height, package = 'recharts',
        dependencies = getDependency(type)
    )

    chart %>% eAxis('x', name = xlab) %>% eAxis('y', name = ylab)
}

#' @export
#' @rdname eChart
echart.default = echart.data.frame

#' @export
#' @rdname eChart
eChart = echart
# from the planet of "Duo1 Qiao1 Yi1 Ge4 Jian4 Hui4 Si3" (will die if having to
# press one more key, i.e. Shift in this case)


#' @export
echartr = function(
    data, x = NULL, y = x, z = NULL, series = NULL, weight = NULL,
    lat = NULL, lng = NULL, type = 'auto', xyflip = FALSE, ...
) {
    # experimental function
    #------------- get all arguments as a list-----------------
    vArgs <- as.list(match.call(expand.dots=TRUE))
    vArgs <- vArgs[3:length(vArgs)]  # exclude `fun` and `data`

    # ------------extract var names and values-----------------
    eval(parse(text=paste0(names(vArgs), "var <- evalVarArg(",
                           sapply(vArgs, deparse), ", data, eval=FALSE)")))
    eval(parse(text=paste0(names(vArgs), " <- evalVarArg(",
                           sapply(vArgs, deparse), ", data)")))
    hasZ <- ! is.null(z)
    if (hasZ) if (! (is.numeric(z[,1]) ||
                            inherits(z[,1], c("Date", "POSIXct", "POSIXlt"))))
        stop("z (timeline) must be numeric or data/time!")

    # ------------------x, y lab(s)----------------------------
    xlab = sapply(xvar, autoArgLabel, auto=deparse(substitute(xvar)))
    ylab = sapply(yvar, autoArgLabel, auto=deparse(substitute(yvar)))

    # -------------split multi-timeline df to lists-----------
    dataVars <- intersect(names(vArgs),
                          c('x', 'y', 'z', 'series', 'weight', 'lat', 'lng', 'type'))
    .makeMetaDataList <- function(df) {
        assignment <- paste0(dataVars, " = ", substitute(df, parent.frame()),
                             "[ ,", paste0(dataVars, "var"), ", drop=FALSE]")
        eval(parse(text=paste0("list(", paste(assignment, collapse=", "), ")")))
    }
    if (hasZ){
        uniZ <- unique(z[,1])
        dataByZ <- split(data, as.factor(z[,1]))
        metaData <- lapply(dataByZ, .makeMetaDataList)
        names(metaData) <- uniZ
    }else{
        metaData <- .makeMetaDataList(data)
    }

    # -----------------determine types---------------------------
    type <- tolower(type)
    stopifnot(all(type %in% c('auto', validChartTypes$name)))
    if (!is.null(series)) lvlSeries <- levels(as.factor(series[,1]))
    if (!is.null(series)) nSeries <- length(lvlSeries) else nSeries <- 1
    if (type == 'auto')  type = determineType(x[,1], y[,1])

    ## type vector: one series, one type
    if (length(type) >= nSeries){
        type <- type[1:nSeries]
    }else{
        type <- c(type, rep(type[length(type)], nSeries-length(type)))
    }

    ## type is converted to a data.frame, colnames:
    ## name type stack xyflip smooth fill sort ribbon roseType mapType mapMode
    dfType <- merge(data.frame(name=type), validChartTypes)
    if (xyflip) type$xyflip <- TRUE

    ## check types
    if (nlevels(as.factor(dfType$type)) > 1){
        if (!all(grepl("^(line|bar|scatter)", dfType$type)))
            stop(paste("Only Cartesion Coordinates charts (scatter/point/bubble,",
                       "line, area, bar) support mixed types"))
    }
    if (nlevels(as.factor(dfType$xyflip)) > 1)
        warning(paste("xyflip is not consistent across the types given.\n",
                      dfType[, "xyflip"]))

    # ---------------------------params list----------------------
    .makeSeriesList <- function(z){  # each timeline create a options list
        series_fun = getFromNamespace(paste0('series_', dfType$type[1]),
                                    'recharts')
        out <- structure(list(
            series <- series_fun(metaData[[z]], type=dfType$type)
        ), meta = metaData[[z]])
        return(out)
    }

    if (hasZ){  ## has timeline

        params = list(
            timeline=list(show=TRUE, y2=50),
            options=lapply(1:length(uniZ), .makeSeriesList)
        )
        if (!is.null(series))
            params$options[[1]]$legend <- list(
                data = as.list(levels(as.factor(series[,1])))
            )

    }else{
        params = .makeSeriesList(1)
        if (!is.null(series))
            params$legend <- list(
                data = as.list(levels(as.factor(series[,1])))
            )
    }


    # -------------------output-------------------------------
    chart = htmlwidgets::createWidget(
        'echarts', params, width = NULL, height = NULL, package = 'recharts',
        dependencies = sapply(c('base', unique(dtType$type)), getDependency)
    )

    if (any(type %in% c('line', 'bar', 'scatter'))){
        chart %>% eAxis('x', name = xlab) %>% eAxis('y', name = ylab)
    }else{
        chart
    }
}


determineType = function(x, y) {
    if (is.numeric(x) && is.numeric(y)) return('scatter')
    # when y is numeric, plot y against x; when y is NULL, treat x as a
    # categorical variable, and plot its frequencies
    if ((is.factor(x) || is.character(x)) && (is.numeric(y) || is.null(y)))
        return('bar')
    if (is.null(x) && is.ts(y)) return('line')
    # FIXME: 'histogram' is not a standard plot type of ECharts
    # http://echarts.baidu.com/doc/doc.html
    if ((is.numeric(x) && is.null(y)) || (is.numeric(y) && is.null(x)))
        return('histogram')
    message('The structure of x:')
    str(x)
    message('The structure of y:')
    str(y)
    stop('Unable to determine the chart type from x and y automatically')
}

# not usable yet; see https://github.com/ecomfe/echarts/issues/1065
getDependency = function(type) {
    if (is.null(type)) return()
    htmltools::htmlDependency(
        'echarts-module', EChartsVersion,
        src = system.file('htmlwidgets/lib/echarts', package = 'recharts'),
        script = sprintf('%s.js', type)
    )
}

getMeta = function(chart) {
    attr(chart$x, 'meta', exact = TRUE)
}
