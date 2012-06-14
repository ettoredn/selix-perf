<?php
require_once("Database.php");
require_once("SystemActivity.php");

class Test
{
    private $id;
    private $sessionId;
    private $configuration;
    private $vhosts;
    private $children;
    private $childRequests;
    private $httpConnections;
    private $httpConnectionsRate;
    private $systemActivity; // Array

    public function __construct( $id )
    {
        if (empty($id) || !is_integer($id))
            throw new ErrorException('empty($id) || !is_integer($id)');

        $q = "SELECT *
              FROM ". Database::TEST_TABLE ."
              WHERE test = :test";
        $st = Database::GetConnection()->prepare($q);
        $st->bindParam(':test', $id, PDO::PARAM_INT);
        if (!$st->execute() || $st->rowCount() != 1) throw new ErrorException("Test $id doesn't exist or is not unique!");
        $st->bindColumn('test', $this->id, PDO::PARAM_INT);
        $st->bindColumn('session', $this->sessionId, PDO::PARAM_INT);
        $st->bindColumn('configuration', $this->configuration, PDO::PARAM_STR);
        $st->bindColumn('vhosts', $this->vhosts, PDO::PARAM_INT);
        $st->bindColumn('children', $this->children, PDO::PARAM_INT);
        $st->bindColumn('child_requests', $this->childRequests, PDO::PARAM_INT);
        $st->bindColumn('perf_connections', $this->httpConnections, PDO::PARAM_INT);
        $st->bindColumn('perf_rate', $this->httpConnectionsRate, PDO::PARAM_INT);

        $st->fetch(PDO::FETCH_BOUND);

        $this->GetSystemActivity();
    }

    public function GetId()
    { return $this->id; }

    public function GetSessionId()
    { return $this->sessionId; }

    public function GetConfiguration()
    { return $this->configuration; }

    public function GetVhosts()
    { return $this->vhosts; }

    public function GetChildren()
    { return $this->children; }

    public function GetChildRequests()
    { return $this->childRequests; }

    public function GetHttpConnections()
    { return $this->httpConnections; }

    public function GetHttpConnectionsRate()
    { return $this->httpConnectionsRate; }

    protected function GetSystemActivity()
    {
        if (empty($this->systemActivity) || !is_array($this->systemActivity))
        {
            $q = "SELECT *
                  FROM ". Database::ACTIVITY_TABLE ."
                  WHERE test=:test
                  ORDER BY seconds_elapsed ASC";
            $st = Database::GetConnection()->prepare($q);
            $st->bindParam(':test', $this->id, PDO::PARAM_INT);
            if (!$st->execute() || $st->rowCount() < 1) throw new ErrorException("Test ".$this->GetId()." doesn't have any system activiy!");
            while ($sa = $st->fetch(PDO::FETCH_ASSOC))
                $this->systemActivity[] = new SystemActivity($sa);
        }

        return $this->systemActivity;
    }

    protected function GetActivity($methodCall)
    {
        if (empty($methodCall) || !is_array($methodCall))
            throw new ErrorException('empty($methodCall) || !is_array($methodCall)');

        $methodName = $methodCall[0];
        $methodArgs = $methodCall[1];
        $result = array();
        foreach ($this->GetSystemActivity() as $a)
        {
            if (!is_callable(array($a, $methodName)))
                throw new ErrorException('!is_callable(array($a, $methodName))');

            $result[] = call_user_func(array($a, $methodName), $methodArgs);
        }

        return $result;
    }

    public function GetCPUUsage()
    {
        $values = $this->GetActivity(array("GetCPUIdle", null));
        foreach ($values as $key => $value)
            $values[$key] = bcsub( "100.00", $value, 2);

        return $values;
    }

    public function GetMemoryUsage()
    {
        $values = $this->GetActivity(array("GetMemoryUsed", null));
        foreach ($values as $key => $value)
            $values[$key] = bcadd( "0.00", $value, 2);

        return $values;
    }

    public function GetMemoryUsageMiB()
    {
        $values = $this->GetActivity(array("GetMemoryUsedKiB", null));
        foreach ($values as $key => $value)
            $values[$key] = bcdiv( $value, "1024", 3);

        return $values;
    }

    public function GetMemoryBuffersMiB()
    {
        $values = $this->GetActivity(array("GetMemoryBuffersKiB", null));
        foreach ($values as $key => $value)
            $values[$key] = bcdiv( $value, "1024", 3);

        return $values;
    }

    public function GetMemoryCachedMiB()
    {
        $values = $this->GetActivity(array("GetMemoryCachedKiB", null));
        foreach ($values as $key => $value)
            $values[$key] = bcdiv( $value, "1024", 3);

        return $values;
    }
}
