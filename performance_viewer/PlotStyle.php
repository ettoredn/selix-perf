<?php

abstract class PlotStyle
{
    abstract public function GetRawCommands();
}

class ClusteredHistogramPlotStyle extends PlotStyle
{
    public function GetRawCommands()
    {
        return '
            set style histogram clustered gap 2
            set style data histograms
            set style fill solid 0.4
            set xtics border nomirror out
        ';
    }
}

class ErrorHistogramPlotStyle extends PlotStyle
{
    public function GetRawCommands()
    {
        return '
            set style histogram errorbars gap 1 lw 1
            set style data histograms
            set style fill solid 0.4
            set bars 8
            set xtics border nomirror out
        ';
    }
}

class PointsPlotStyle extends PlotStyle
{
    private $pointSize;

    public function __construct( $size = 1 )
    {
        if (!empty($size))
            $this->pointSize = $size;
    }

    public function GetRawCommands()
    {
        return '
            set pointsize '. $this->pointSize .'
            set style data points
        ';
    }
}

class LinesPointsPlotStyle extends PlotStyle
{
    private $pointSize;

    public function __construct( $size = 1 )
    {
        if (!empty($size))
            $this->pointSize = $size;
    }

    public function GetRawCommands()
    {
        return '
            set pointsize '. $this->pointSize .'
            set style data linespoints
        ';
    }
}

class LinesPlotStyle extends PlotStyle
{
    public function GetRawCommands()
    {
        return '
            set style data lines
        ';
    }
}
