<?php
require_once("Database.php");
require_once("Test.php");
require_once("TestSetUtils.php");
require_once("Gnuplot.php");

class Session
{
    private $id;
    private $httpConnections;
    private $httpConnectionsRate;
    private $test; // Array

    public function __construct( $id )
    {
        if (empty($id) || !is_integer($id))
            throw new ErrorException('empty($id) || !is_integer($id)');

        $q = "SELECT *
              FROM ". Database::TEST_TABLE ."
              WHERE session = :session";
        $st = Database::GetConnection()->prepare($q);
        $st->bindParam(':session', $id, PDO::PARAM_INT);
        if (!$st->execute() || $st->rowCount() < 1) throw new ErrorException("Session $id doesn't exist!");
        $st->bindColumn('test', $testId, PDO::PARAM_INT);

        while ($st->fetch(PDO::FETCH_BOUND))
            $this->test[] = new Test($testId);

        $this->id = $id;
        // Every test in a session must have the same connections number and ratio
        $this->httpConnections = $this->test[0]->GetHttpConnections();
        $this->httpConnectionsRate = $this->test[0]->GetHttpConnectionsRate();
    }

    public function GetId()
    { return $this->id; }

    protected function GetTests()
    { return $this->test; }

    public function ConfigurationExists( $conf )
    {
        if (empty($conf))
            throw new ErrorException('empty($conf)');

        foreach ($this->test as $test)
            if ($test->GetConfiguration() == $conf)
                return true;

        return false;
    }

    /**
     * @param string $property
     * @param array $filter array( methodName => array( methodArgs, filterValue ) )
     * @param array $groupByProperty array( methodName => methodArgs )
     * @return array array( groupByValue => propertyValue )
     */
    public function GetData( $property, $filter, $groupByProperty )
    {
        if (empty($property))
            throw new ErrorException('empty($property)');
        if (!is_array($filter) || count($filter) < 1)
            throw new ErrorException('!is_array($filter) || count($filter) < 1');

        if (!is_array($groupByProperty) || count($groupByProperty) != 1)
            throw new ErrorException('Invalid arguments!');

        $testSet = $this->test;
        // Filter
        foreach ($filter as $methodName => $args)
        {
            if (!is_array($args) || count($args) != 2)
                throw new ErrorException('!is_array($args) || count($args) != 2');
            $testSet = TestSetUtils::FilterBy($testSet, array($methodName, $args[0]), $args[1]);
        }
        // Group by
        $keys = array_keys($groupByProperty);
        $values = array_values($groupByProperty);
        $testSet = TestSetUtils::GroupBy($testSet, array($keys[0], $values[0]));

        // Get property values
        $res = array();
        foreach ($testSet as $groupByValue => $testArray)
        {
            // There must be only one test for each groupByProperty value in each session
            if (count($testArray) != 1)
                throw new ErrorException('count($testArray) != 1');
            $test = $testArray[0];

            if (!is_callable(array($test, $property)))
                throw new ErrorException('!is_callable(array($test, $property))');
            $res[$groupByValue] = call_user_func(array($test, $property), null);
        }

        return $res;
    }

    /**
     * @param string $resourceProperty
     * @param array $filterBy
     * @param string $groupByProperty
     * @return string PNG image filename
     * @throws ErrorException
     */
    public function PlotRelativeResourceUsage( $resourceProperty, $filterBy, $groupByProperty )
    {
        if (empty($resourceProperty) || !is_array($filterBy) || count($filterBy) < 1 || empty($groupByProperty))
            throw new ErrorException('empty($resourceProperty) || !is_array($filterBy) || count($filterBy) < 1 || empty($groupByProperty)');

        // Supports only one filter criteria
        $filterByProperty = array_keys($filterBy)[0];
        $filterByValue = array_values($filterBy)[0];

        $filename = $this->GetId()."_".$resourceProperty."_".$filterByProperty."_".$filterByValue."_".$groupByProperty.".png";
        $cleanResource = preg_replace('/^Get/', '', $resourceProperty);
        $cleanFilter = strtolower(preg_replace('/^Get/', '', $filterByProperty));
        $cleanGroupBy = strtolower(preg_replace('/^Get/', '', $groupByProperty));
        $title = $cleanResource ." with $cleanFilter $filterByValue  (".($this->httpConnectionsRate)." requests/sec)";

        // If already generated returns it
        if (file_exists(Gnuplot::DATAPATH.$filename) && !$GLOBALS['disable_cache'])
            return Gnuplot::DATAPATH.$filename;

        $data = $this->GetData($resourceProperty, array($filterByProperty => array(null, $filterByValue)), array($groupByProperty => null));
        if (empty($data) || !is_array($data))
            throw new ErrorException("[".__METHOD__."] empty data set!");

        // Build plot data for gnuplot
        $plotData = array(array());

        // Write entries by column
        $column = 0;
        foreach ($data as $groupedValue => $values)
        {
            // Header
            $plotData[$column][] = "\"$cleanGroupBy = $groupedValue\"";

            foreach ($values as $sa)
                $plotData[$column][] = $sa;

            $column++;
        }

        /*
         * Transforms $plotData in an array where each entry represents a row.
         */
        // The number of samples is taken from the smallest set
        $samples = count($plotData[0]);
        foreach ($plotData as $columnData)
            if (count($columnData) < $samples)
                $samples = count($columnData);

        $res = array();
        for ($row=0; $row < $samples; $row++)
            foreach ($plotData as $column => $columnData)
                    $res[$row][$column] = $columnData[$row];

        // Implode entries
        foreach ($res as $key => $entry)
            $plotData[$key] = implode(" ", $entry);

//        print_r($plotData);

        // Build plot arguments
        $plotArgs = array();
        $plotDataArgs = array();
        for ($i=0; $i < count($data); $i++)
        {
            $plotArgs[] =
                    'using :($'.($i+1).') title columnhead('.($i+1).') smooth csplines';
            $plotDataArgs[] = $plotData; // $plotData must be repeated for each configuration
        }
//        print_r(implode("\n", $plotArgs));

        $plot = new Gnuplot();
        $plot->Open();
        $plot->SetPlotStyle(new LinesPlotStyle()); // Reset
        $plot->SetYLabel("usage [%]");
        $plot->SetXLabel("time [seconds]");
        $plot->SetYRange(0, "100");
        $plot->PlotDataToPNG($title, $filename, $plotArgs, $plotDataArgs, "1024,768");
        $plot->Close();
//        print_r(implode("\n",$plot->GetLog()));

        return Gnuplot::DATAPATH.$filename;
    }

    /**
     * @param string $resourceProperty
     * @param array $filterBy
     * @param string $groupByProperty
     * @return string PNG image filename
     * @throws ErrorException
     */
    public function PlotResourceUsage( $resourceProperty, $filterBy, $groupByProperty )
    {
        if (empty($resourceProperty) || !is_array($filterBy) || count($filterBy) < 1 || empty($groupByProperty))
            throw new ErrorException('empty($resourceProperty) || !is_array($filterBy) || count($filterBy) < 1 || empty($groupByProperty)');

        // Supports only one filter criteria
        $filterByProperty = array_keys($filterBy)[0];
        $filterByValue = array_values($filterBy)[0];

        $filename = $this->GetId()."_".$resourceProperty."_".$filterByProperty."_".$filterByValue."_".$groupByProperty.".png";
        $cleanResource = preg_replace('/^Get/', '', $resourceProperty);
        $cleanFilter = strtolower(preg_replace('/^Get/', '', $filterByProperty));
        $cleanGroupBy = strtolower(preg_replace('/^Get/', '', $groupByProperty));
        $title = $cleanResource ." with $cleanFilter $filterByValue  (".($this->httpConnectionsRate)." requests/sec)";

        // If already generated returns it
        if (file_exists(Gnuplot::DATAPATH.$filename) && !$GLOBALS['disable_cache'])
            return Gnuplot::DATAPATH.$filename;

        $data = $this->GetData($resourceProperty, array($filterByProperty => array(null, $filterByValue)), array($groupByProperty => null));
        if (empty($data) || !is_array($data))
            throw new ErrorException("[".__METHOD__."] empty data set!");

        // Build plot data for gnuplot
        $plotData = array(array());

        // Write entries by column
        $column = 0;
        foreach ($data as $groupedValue => $values)
        {
            // Header
            $plotData[$column][] = "\"$cleanGroupBy = $groupedValue\"";

            foreach ($values as $sa)
                $plotData[$column][] = $sa;

            $column++;
        }

        /*
         * Transforms $plotData in an array where each entry represents a row.
         */
        // The number of samples is taken from the smallest set
        $samples = count($plotData[0]);
        foreach ($plotData as $columnData)
            if (count($columnData) < $samples)
                $samples = count($columnData);

        $res = array();
        for ($row=0; $row < $samples; $row++)
            foreach ($plotData as $column => $columnData)
                    $res[$row][$column] = $columnData[$row];

        // Implode entries
        foreach ($res as $key => $entry)
            $plotData[$key] = implode(" ", $entry);

    //        print_r($plotData);

        // Build plot arguments
        $plotArgs = array();
        $plotDataArgs = array();
        for ($i=0; $i < count($data); $i++)
        {
            $plotArgs[] =
                    'using :($'.($i+1).') title columnhead('.($i+1).') smooth csplines';
            $plotDataArgs[] = $plotData; // $plotData must be repeated for each configuration
        }
    //        print_r(implode("\n", $plotArgs));

        $plot = new Gnuplot();
        $plot->Open();
        $plot->SetPlotStyle(new LinesPlotStyle()); // Reset
        $plot->SetYLabel("usage [MiB]");
        $plot->SetXLabel("time [seconds]");
        $plot->PlotDataToPNG($title, $filename, $plotArgs, $plotDataArgs, "1024,768");
        $plot->Close();
    //        print_r(implode("\n",$plot->GetLog()));

        return Gnuplot::DATAPATH.$filename;
    }
}
