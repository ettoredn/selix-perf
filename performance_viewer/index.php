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

    try {
        $s = new Session( $id );
    } catch (ErrorException $e)
    { die("<p>Session $id doesn't exist</p>"); }

    $cpuUsage = $s->PlotRelativeResourceUsage("GetCPUUsage", array("GetConfiguration" => "fpm"), "GetVhosts");
    $memoryUsage = $s->PlotRelativeResourceUsage("GetMemoryUsage", array("GetConfiguration" => "fpm"), "GetVhosts");
    $raw = $s->GetData("GetMemoryUsage", array("GetConfiguration" => array(null, "fpm")), array("GetVhosts" => null));

    // Get verbose output produced
    $verbose = ob_get_clean();

    echo "<img src='$cpuUsage' width='731' height='549'/>";
    echo "<img src='$memoryUsage' width='731' height='549'/>";

    echo '<p><a href="javascript:void(0)" onclick="switchRawData();">Show/hide raw data</a></p>';
    echo "<pre id='rawData' style='display: none;'>".print_r($raw, true)."</pre>";
    echo '<p><a href="javascript:void(0)" onclick="switchLog();">Show/hide log</a></p>';
    echo "<pre id='log' style='display: none;'>".$verbose."</pre>";

}
?>
 </body>
 </html>
