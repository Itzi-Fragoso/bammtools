
#############################################################
#
#	plotRateThroughTime <- function(...)
#
#	ephy = object of class 'bammdata' or 'bamm-ratematrix'
#		if bamm-ratematrix, start.time, end.time, node, nslices, nodetype are not used.
#	useMedian = boolean, will plot median if TRUE, mean if FALSE.
#	intervals if NULL, no intervals will be plotted, otherwise a vector of quantiles must be supplied (these will define shaded polygons)
#	ratetype = autodetects diversification vs traits (based on input object 'type'), if 'auto', defaults to speciation (for diversification) or beta (for traits). Can alternatively specify 'netdiv' or 'extinction'. 
#	nBins = number of time slices used to generate rates through time
#	smooth = boolean whether or not to apply loess smoothing
#	smoothParam = loess smoothing parameter, ignored if smooth = F
#	opacity = opacity of color for interval polygons
#	intervalCol = transparent color for interval polygons
#	avgCol = color for mean/median line
#	start.time = start time to be fed to getRateThroughTimeMatrix
#	end.time = end time to be fed to getRateThroughTimeMatrix
#	node = if supplied, the clade descended from this node will be used.
#	nodetype = supplied to getRateThroughTimeMatrix
#	plot = boolean: if TRUE, a plot will be returned, if FALSE, the data for the plot will be returned. 
#	xticks = number of ticks on the x-axis.
#	yticks = number of ticks on the y-axis.
#	xlim = vector of length 2 with min and max times for x axis. X axis is time since present, so if plotting till the present, xlim[2]==0. Can also be 'auto'.
#	ylim = vector of length 2 with min and max rates for y axis. Can also be 'auto'. 
#	add = boolean: should rates be added to an existing plot
#
#	+ several undocumented args to set plot parameters: mar, cex, xline, yline, etc.
#	

plotRateThroughTime <- function(ephy, useMedian = FALSE, intervals=seq(from = 0,to = 1,by = 0.01), ratetype = 'auto', nBins = 100, smooth = FALSE, smoothParam = 0.20, opacity = 0.01, intervalCol='blue', avgCol='red',start.time = NULL, end.time = NULL, node = NULL, nodetype='include', plot = TRUE, cex.axis=1, cex=1.3, xline=3.5, yline=3.5, mar=c(6,6,1,1), xticks=5, yticks=5, xlim='auto', ylim='auto',add=FALSE) {
	
	if (!any(c('bammdata', 'bamm-ratematrix') %in% class(ephy))) {
		stop("ERROR: Object ephy must be of class 'bammdata' or 'bamm-ratematrix'.\n");
	}
	if (!is.logical(useMedian)) {
		stop('ERROR: useMedian must be either TRUE or FALSE.');
	}
	if (!any(c('numeric', 'NULL') %in% class(intervals))) {
		stop("ERROR: intervals must be either 'NULL' or a vector of quantiles.");
	}
	if (!is.logical(smooth)) {
		stop('ERROR: smooth must be either TRUE or FALSE.');
	}
	
	if ('bammdata' %in% class(ephy)) {
		#get rates through binned time
		rmat <- getRateThroughTimeMatrix(ephy, start.time = start.time, end.time = end.time,node = node, nslices = nBins, nodetype=nodetype);
	}
	if ('bamm-ratematrix' %in% class(ephy)) {
		if (!any(is.null(c(start.time, end.time, node)))) {
			stop('ERROR: You cannot specify start.time, end.time or node if the rate matrix is being provided. Please either provide the bammdata object instead or specify start.time, end.time or node in the creation of the bamm-ratematrix.')
	}
		#use existing rate matrix
		rmat <- ephy;
	}

	#set appropriate rates
	if (ratetype != 'auto' & ratetype != 'extinction' & ratetype != 'netdiv') {
		stop("ERROR: ratetype must be 'auto', 'extinction', or 'netdiv'.\n");
	}
	if (ephy$type == 'trait' & ratetype != 'auto') {
		stop("ERROR: If input object is of type 'trait', ratetype can only be 'auto'.")
	}
	if (ratetype == 'auto' & ephy$type == 'diversification') {
		rate <- rmat$lambda;
		ratelabel <- 'Speciation';
	}
	if (ratetype == 'auto' & ephy$type == 'trait') {
		rate <- rmat$beta;
		ratelabel <- 'trait rate';
	}
	if (ratetype == 'extinction') {
		rate <- rmat$mu;
		ratelabel <- 'Extinction';
	}
	if (ratetype == 'netdiv') {
		rate <- rmat$lambda - rmat$mu;
		ratelabel <- 'Net diversification';
	}

	#generate coordinates for polygons
	maxTime <- max(rmat$times);
	if (!is.null(intervals)) {
		mm <- apply(rate, MARGIN = 2, quantile, intervals);

		poly <- list();
		q1 <- 1;
		q2 <- nrow(mm);
		repeat {
			if (q1 >= q2) {break}
			a <- as.data.frame(cbind(rmat$times,mm[q1,]));
			b <- as.data.frame(cbind(rmat$times,mm[q2,]));
			b <- b[rev(rownames(b)),];
			colnames(a) <- colnames(b) <- c('x','y');
			poly[[q1]] <- rbind(a,b);
			q1 <- q1 + 1;
			q2 <- q2 - 1;
		}
	}

	#Calculate averaged data line
	if (!useMedian) {
		avg <- colMeans(rate);
	} else {
		avg <- unlist(apply(rate,2,median));
	}
	
	#apply loess smoothing to intervals
	if (smooth) {
		for (i in 1:length(poly)) {
			p <- poly[[i]];
			rows <- nrow(p);
			p[1:rows/2,2] <- loess(p[1:rows/2,2] ~ p[1:rows/2,1],span = smoothParam)$fitted;
			p[(rows/2):rows,2] <- loess(p[(rows/2):rows,2] ~ p[(rows/2):rows,1],span = smoothParam)$fitted;
			poly[[i]] <- p;
		}
		avg <- loess(avg ~ rmat$time,span = smoothParam)$fitted;
	}

	#begin plotting
	if (plot) {
		if (!add) {
			plot.new();
			par(mar=mar);
			if (unique(xlim == 'auto') & unique(ylim == 'auto')) {
				plot.window(xlim=c(maxTime, 0), ylim=c(0 , max(poly[[1]][,2])));
				xMin <- maxTime;
				xMax <- 0;
				yMin <- 0;
				yMax <- max(poly[[1]][,2]);
			}
			if (unique(xlim != 'auto') & unique(ylim == 'auto')) {
				plot.window(xlim = xlim, ylim=c(0 , max(poly[[1]][,2])));
				xMin <- xlim[1];
				xMax <- xlim[2];
				yMin <- 0;
				yMax <- max(poly[[1]][,2]);
			}
			if (unique(xlim == 'auto') & unique(ylim != 'auto')) {
				plot.window(xlim=c(maxTime, 0), ylim=ylim);
				xMin <- maxTime;
				xMax <- 0;
				yMin <- ylim[1];
				yMax <- ylim[2];
			}
			axis(at=c(1.3*xMin,round(seq(xMin,xMax, length.out=xticks+1))), labels = c(1.3*xMin,round(seq(xMin, xMax, length.out=xticks+1))), cex.axis = cex.axis, side = 1);
			axis(at=c(-0.2,seq(yMin, 1.2*yMax, length.out=yticks+1)), labels = c(-0.2,round(seq(yMin, 1.2*yMax, length.out=yticks+1),digits=1)), las=1, cex.axis = cex.axis, side = 2);

			mtext(side = 1, text = 'Time since present', line = xline, cex = cex);
			mtext(side = 2, text = ratelabel, line = yline, cex = cex);

		}
		#plot intervals
		if (!is.null(intervals)) {
			for (i in 1:length(poly)) {
				polygon(x=maxTime - poly[[i]][,1],y=poly[[i]][,2],col=transparentColor(intervalCol,opacity),border=NA);
			}
		}
		lines(x = maxTime - rmat$time, y = avg, lwd = 3, col = avgCol);
	} else {
		return(list(poly = poly,avg = avg,times = rmat$time));
	}
}
