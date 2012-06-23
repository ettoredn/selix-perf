<?php
//require_once("Database.php");
require_once("Test.php");
require_once("TestSetUtils.php");
require_once("Session.php");
$verbose = true;
$verbose_maths = false;
$disable_cache = true;
?>
<!DOCTYPE html>
 <html>
 <head>
 <title>Benchmark Viewer</title>
     <script type="text/javascript">
         function switchLog()
         {
             var e = document.getElementById('log');
             if (e.style.display == "none") e.style.display = "block";
             else e.style.display = "none";
             return false;
         }
         function switchRawData()
         {
             var e = document.getElementById('rawData');
             if (e.style.display == "none") e.style.display = "block";
             else e.style.display = "none";
             return false;
         }
         function focusSessionSelect()
         {
             var e = document.getElementById('sessionSelect');
             e.focus();
         }
     </script>
     <style type="text/css">
         select.sessions {
             width: 100%;
             text-align: center;
             font-family: "Lucida Console";
         }
     </style>
 </head>
 <body onload="focusSessionSelect();">
<?php

// Generate benchmarks list
$q = "SELECT session AS id, COUNT(test) AS tests, perf_rate AS rate
      FROM ". Database::TEST_TABLE ."
      GROUP BY session
      ORDER BY session DESC";
$st = Database::GetConnection()->prepare($q);
if (!$st->execute())
    throw new ErrorException("Error executing query: $q");
if($st->rowCount() < 1)
    echo '<p>No session present in the database</p>';
else
{
    $st->bindColumn('id', $sessionId, PDO::PARAM_INT);
    $st->bindColumn('tests', $sessionTestsCount, PDO::PARAM_INT);
    $st->bindColumn('rate', $sessionConnectionsRate, PDO::PARAM_INT);
    echo '
    <form method="get">
        <select id="sessionSelect" name="session" size="6" class="sessions" onchange="this.form.submit()">
            <option disabled="disabled">'.
            str_replace(" ", "&nbsp;", sprintf("%-16s%-18s%-10s%-10s", "ID", "DATE", "TESTS", "CONNECTIONS RATE")).
            '</option>';

    while ($st->fetch(PDO::FETCH_BOUND))
    {
        $id = str_replace(" ", "&nbsp;", sprintf("%-13s", $sessionId));
        $date = str_replace(" ", "&nbsp;", sprintf("%-27s", date("Y-m-d H:i:s", $sessionId)));
        $tests = str_replace(" ", "&nbsp;", sprintf("%-15s", $sessionTestsCount));
        $connRate = str_replace(" ", "&nbsp;", sprintf("%-14s", $sessionConnectionsRate));

        echo '<option value="'. $sessionId .
                ( !empty($_GET['session']) && $_GET['session'] == $sessionId ? '" selected="selected">' : '">' ).
                $id.$date.$tests.$connRate.'</option>';
    }

    echo '
        </select>
        <!-- <input type="submit" value="Show benchmark" /> -->
    </form>';
 }

// Show benchmark if requested
if (!empty($_GET['session']))
{
    // Retrieve start and finish timestamps for each benchmark run
    $id = (int) $_GET['session'];

    // Catch verbose output
    ob_start();

    try {
        $s = new Session( $id );
    } catch (ErrorException $e)
    { die("<p>Session $id doesn't exist</p>"); }

    if ($s->ConfigurationExists("fpm"))
    {
        $cpuUsage = $s->PlotRelativeResourceUsage("GetCPUUsage", array("GetConfiguration" => "fpm"), "GetVhosts");
        $memoryUsage = $s->PlotResourceUsage("GetMemoryUsageMiB", array("GetConfiguration" => "fpm"), "GetVhosts");
    }
    if ($s->ConfigurationExists("fpm_selix"))
    {
        $selixCPUUsage = $s->PlotRelativeResourceUsage("GetCPUUsage", array("GetConfiguration" => "fpm_selix"), "GetChildren");
        $selixMemoryUsage = $s->PlotResourceUsage("GetMemoryUsageMiB", array("GetConfiguration" => "fpm_selix"), "GetChildren");
    }
    if ($s->ConfigurationExists("modselinux"))
    {
        $modselinuxCPUUsage = $s->PlotRelativeResourceUsage("GetCPUUsage", array("GetConfiguration" => "modselinux"), "GetVhosts");
        $modselinuxMemoryUsage = $s->PlotResourceUsage("GetMemoryUsageMiB", array("GetConfiguration" => "modselinux"), "GetVhosts");
    }

    $raw = $s->GetData("GetMemoryUsageMiB", array("GetConfiguration" => array(null, "fpm")), array("GetVhosts" => null));

    // Get verbose output produced
    $verbose = ob_get_clean();

    if ($s->ConfigurationExists("fpm"))
    {
        echo "<img src='$cpuUsage' width='731' height='549'/>";
        echo "<img src='$memoryUsage' width='731' height='549'/>";
//        echo "<img src='$fpmMemoryBuffers' width='731' height='549'/>";
//        echo "<img src='$fpmMemoryCached' width='731' height='549'/>";
    }
    if ($s->ConfigurationExists("fpm_selix"))
    {
        echo "<img src='$selixCPUUsage' width='731' height='549'/>";
        echo "<img src='$selixMemoryUsage' width='731' height='549'/>";
    }
    if ($s->ConfigurationExists("modselinux"))
    {
        echo "<img src='$modselinuxCPUUsage' width='731' height='549'/>";
        echo "<img src='$modselinuxMemoryUsage' width='731' height='549'/>";
    }

    echo '<p><a href="javascript:void(0)" onclick="switchRawData();">Show/hide raw data</a></p>';
    echo "<pre id='rawData' style='display: none;'>".print_r($raw, true)."</pre>";
    echo '<p><a href="javascript:void(0)" onclick="switchLog();">Show/hide log</a></p>';
    echo "<pre id='log' style='display: none;'>".$verbose."</pre>";
}
?>
 </body>
 </html>
