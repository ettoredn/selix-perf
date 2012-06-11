<?php
require_once('PlotStyle.php');

class Gnuplot
{
    const DATAPATH = "data/";
    private $gnuplotPath;
    private $gnuplotHandle = FALSE;
    private $gnuplotPipes;
    private $log;

    public function __construct( $pathname = "/usr/bin/gnuplot" )
    {
        if (!empty($pathname))
            $this->gnuplotPath = $pathname;
    }

    private function GetExecutable()
    { return $this->gnuplotPath; }

    /*
     * Open gnuplot process.
     */
    public function Open()
    {
        $this->gnuplotHandle = proc_open($this->GetExecutable(),
            array(
                0 => array("pipe", "r"), // stdin is a pipe that the child will read from
//                1 => array("pipe", "w"), // stderr is a pipe that the child will write to
//                2 => array("pipe", "w"), // stderr is a pipe that the child will write to
            ),
            $this->gnuplotPipes
        );
        if (!$this->gnuplotHandle)
            throw new ErrorException('Unable to execute gnuplot');
    }

    /*
     * Close gnuplot process.
     */
    public function Close()
    {
        if (!$this->gnuplotHandle)
            return;

        $this->WriteLine('quit');
        fclose( $this->gnuplotPipes[0]);
        proc_close($this->gnuplotHandle);
    }

    public function GetLog()
    {
        $log = array();

        foreach($this->log as $l)
            foreach(explode("\n", $l) as $line)
                    if (strlen(trim($line)) > 0)
                        $log[] = trim($line);
        return $log;
    }

    /*
     * Sends a command to gnuplot.
     */
    protected function WriteLine( $cmd )
    {
        if (!$this->gnuplotHandle)
            throw new ErrorException('!$this->gnuplotHandle');

        $res = fwrite($this->gnuplotPipes[0], $cmd."\n");
        if (!$res)
            throw new ErrorException('Gnuplot write failed');

        $this->log[] = $cmd;
    }

    public function Reset()
    { $this->WriteLine('reset'); }

    /*
     * Resets settings with supplied style.
     */
    public function SetPlotStyle( PlotStyle $style )
    {
        $this->Reset();
        $this->WriteLine($style->GetRawCommands());
    }

    /*
     * Both min and max must be specified.
     */
    public function SetXRange( $min, $max )
    {
        if (!isset($min) || !isset($max))
            throw new ErrorException('!isset($min) || !isset($max)');

        $this->WriteLine('set xrange ['. $min .':'. $max .']');
    }
    public function SetYRange( $min, $max )
    {
        if (!isset($min) || !isset($max))
            throw new ErrorException('!isset($min) || !isset($max)');

        $this->WriteLine('set yrange ['. $min .':'. $max .']');
    }

    public function SetXLabel( $label )
    { $this->WriteLine('set xlabel "'. $label .'"'); }
    public function SetYLabel( $label )
    { $this->WriteLine('set ylabel "'. $label .'"'); }

    /*
     * Invokes 'plot "-" $args' command providing $data
     * Each element of $dataSets represents a data set which is an array of elements representing each entry.
     */
    public function PlotDataToPNG( $title, $filename, $args, $dataSets, $size = "640,480" )
    {
        if (!is_array($args) || !is_array($dataSets) || count($dataSets) < 1 || strstr($filename, "/") != FALSE)
            throw new ErrorException('!is_array($args) || !is_array($data) || count($data) < 1 || strstr($filename, "/")');

        $this->WriteLine('
            set terminal push
            set terminal png size '. $size .'
            set output "'. self::DATAPATH.$filename .'"
            set title "'. $title .'"
            plot "-" '. implode(', "" ', $args) .'
        ');

        foreach ($dataSets as $block)
        {
            foreach($block as $entry)
                $this->WriteLine($entry);
            $this->WriteLine("e");
        }

        $this->WriteLine('
            set output
            set terminal pop
        ');
    }
}
