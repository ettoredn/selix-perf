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
//$q = "SELECT session id, benchmarks, runs, description
//      FROM ". Database::SESSION_TABLE ."
//      ORDER BY id DESC";
//$sessions = Database::GetConnection()->query($q) or die("Query error: $q");

//if ($sessions->rowCount() < 1)
//    echo '<p>No session present in the database</p>';
//else
//{
//    echo '
//    <form method="get">
//        <select id="sessionSelect" name="bench" size="6" class="sessions" onchange="this.form.submit()">
//            <option disabled="disabled">'.
//            str_replace(" ", "&nbsp;", sprintf("%-16s%-15s%-31s%-52s%-30s", "ID", "DATE", "RUNS", "BENCHMARKS", "DESCRIPTION")).
//            '</option>';
//
//    while($s = $sessions->fetch())
//    {
//        $id = str_replace(" ", "&nbsp;", sprintf("%-13s", $s['id']));
//        $date = str_replace(" ", "&nbsp;", sprintf("%-22s", date("Y-m-d H:i:s", $s['id'])));
//        $runs = str_replace(" ", "&nbsp;", sprintf("%-7s", $s['runs']));
//        $benchmarks = str_replace(" ", "&nbsp;", sprintf("%-60s", $s['benchmarks']));
//        $description = str_replace(" ", "&nbsp;", sprintf("%-50s", ($s['description'] == null ? "" : $s['description'])));
//
//        echo '<option value="'. $s['id'] .
//                ( !empty($_GET['bench']) && $_GET['bench'] == $s['id'] ? '" selected="selected">' : '">' ).
//                $id.$date.$runs.$benchmarks.$description.'</option>';
//    }
//
//    echo '
//        </select>
//        <!-- <input type="submit" value="Show benchmark" /> -->
//    </form>';
//}

// Show benchmark if requested
if (!empty($_GET['session']))
{
    // Retrieve start and finish timestamps for each benchmark run
    $id = (int) $_GET['session'];

    // Catch verbose output
    ob_start();

    $s = new Session($id);
    $cpuUsage = $s->PlotCPUUsageByConfig( "fpm", "vhosts" );
//    $tests = $s->GetTests();
//    $byConfig = TestSetUtils::FilterBy($tests, array("GetConfiguration", null), "iotest");
//    $byConfig = $tests;
//    print_r( TestSetUtils::GroupBy($byConfig, array("GetVhosts", null)));

    // Plot CPU usage of tests with different number of vhosts and fixed configuration
//    $s->PlotCPUByConfig("config");

    // Plot CPU usage of tests with different configurations and fixed number of vhosts
//    $s->PlotCPUByVhosts(20);


//    try {
//        $s = new Session( $id );
//    } catch (ErrorException $e)
//    { die("<p>Session $id doesn't exist</p>"); }
//
//    $raw = $s->GetRawResults();
//    $helloworld = $s->PlotBenchmark("helloworld", array(
//        "zend_compile",
//        "zend_execute",
//    ));
//    $compile = $s->PlotBenchmark("compile", array(
//        "zend_first_compile",
//        "zend_compile",
//    ));
//    $function = $s->PlotBenchmark("function", array(
////        "zendvm_first_user_fcall",
//        "zendvm_user_fcall",
//        "zendvm_internal_fcall",
//    ));
//    $helloworldDelta = $s->PlotBenchmarkDelta("helloworld", array(
//        "zend_compile",
//        "zend_execute",
//    ), "php");
//    $compileDelta = $s->PlotBenchmarkDelta("compile", array(
//        "zend_first_compile",
//        "zend_compile",
//    ), "php");
//    $functionDelta = $s->PlotBenchmarkDelta("function", array(
////        "zendvm_first_user_fcall",
//        "zendvm_user_fcall",
//        "zendvm_internal_fcall",
//    ), "php");

    // Get verbose output produced
    $verbose = ob_get_clean();

    echo "<img src='$cpuUsage' width='731' height='549'/>";
//    echo "<img src='$compile' width='731' height='549'/>";
//    echo "<img src='$function' width='731' height='549'/>";
//    echo "<img src='$helloworldDelta' width='731' height='549'/>";
//    echo "<img src='$compileDelta' width='731' height='549'/>";
//    echo "<img src='$functionDelta' width='731' height='549'/>";

    echo '<p><a href="javascript:void(0)" onclick="switchRawData();">Show/hide raw data</a></p>';
    echo "<pre id='rawData' style='display: none;'>".print_r($raw, true)."</pre>";
    echo '<p><a href="javascript:void(0)" onclick="switchLog();">Show/hide log</a></p>';
    echo "<pre id='log' style='display: none;'>".$verbose."</pre>";

}
?>
 </body>
 </html>
