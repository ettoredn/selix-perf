<?php

class SystemActivity
{
//    private $testId;
    private $configuration;
    private $CPUUser;
    private $CPUSystem;
    private $CPUIOwait;
    private $CPUIdle;
    private $memUsedKiB;
    private $memUsed;
    private $memBuffersKiB;
    private $memCachedKiB;
    private $secondsElapsed;

    public function __construct( $sa )
    {
        if (empty($sa) || !is_array($sa))
            throw new ErrorException('empty($sa) || !is_array($sa)');

//        $this->testId = $sa['test'];
//        $this->configuration = $sa['configuration'];
        $this->CPUUser = $sa['cpu_user'];
        $this->CPUSystem = $sa['cpu_system'];
        $this->CPUIOwait = $sa['cpu_iowait'];
        $this->CPUIdle = $sa['cpu_idle'];
        $this->memUsedKiB = $sa['mem_used_kb'];
        $this->memUsed = $sa['mem_used'];
        $this->memBuffersKiB = $sa['mem_buffers_kb'];
        $this->memCachedKiB = $sa['mem_cached_kb'];
        $this->secondsElapsed = $sa['seconds_elapsed'];
    }

//    public function GetTestId()
//    { return $this->testId; }

//    public function GetConfiguration()
//    { return $this->configuration; }

    public function GetCPUUser()
    { return $this->CPUUser; }

    public function GetCPUSystem()
    { return $this->CPUSystem; }

    public function GetCPUIOWait()
    { return $this->CPUIOwait; }

    public function GetCPUIdle()
    { return $this->CPUIdle; }

    public function GetMemoryUsed()
    { return $this->memUsed; }

    public function GetMemoryUsedKiB()
    {
        return $this->memUsedKiB;
//        return $this->memUsedKiB - $this->memBuffersKiB - $this->memCachedKiB;
    }

    public function GetMemoryBuffersKiB()
    { return $this->memBuffersKiB; }

    public function GetMemoryCachedKiB()
    { return $this->memCachedKiB; }

    public function GetSecondsElapsed()
    { return $this->secondsElapsed; }
}
