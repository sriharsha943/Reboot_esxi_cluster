function RestartCluster ($cluster) {
    if ($cluster) {
        #select vmhosts from cluster
        $vmhosts = get-cluster $cluster | Get-VMHost 
        $vmhostcount = $vmhosts.Count
        if ($vmhostcount -ge 2) {
             $vmhostpercentage = 100/$vmhostcount   
             foreach ($vmhost in $vmhosts) {
                $percentagecomplete += $vmhostpercentage
                $vmhostobj = get-vmhost -Name $vmhost
                Write-Progress -Activity "restart cluster $($cluster.name)" -Status "rebooting vmhost $($vmhostobj.name)" -PercentComplete $percentagecomplete
            
                #enter maintenance mode/evacuate
                Set-VMhost $vmhostobj -State maintenance -Evacuate -VsanDataMigrationMode Full -Confirm:$false | Out-Null

                #wait for maintenance mode/evacuate
                do {
                    sleep 10
                    $ConnectionState = (get-vmhost $vmhostobj).ConnectionState
                }
                while ($ConnectionState -eq "Connected")

                #reboot vmhost
                Restart-VMHost -VMHost $vmhostobj -Confirm:$false |Out-Null

                #wait for not responding state
                do {
                    sleep 10
                    $ConnectionState = (get-vmhost $vmhostobj).ConnectionState
                }
                while ($ConnectionState -eq "Maintenance")

                #wait for maintenance mode state
                do {
                    sleep 10
                    $ConnectionState = (get-vmhost $vmhostobj).ConnectionState
                }
                while ($ConnectionState -eq "NotResponding")

                #exit maintenance mode
                Set-VMhost $vmhostobj -State Connected -Confirm:$false | Out-Null

                #wait for connected state
                do {
                    sleep 10
                    $ConnectionState = (get-vmhost $vmhostobj).ConnectionState
                }
                while ($ConnectionState -eq "Maintenance")
            }    
        }
        else {write-host "Cluster contain to less hosts for sequential reboots, use Restart-VMHost cmdlet instead"}
    }
}

$cluster = get-cluster | Out-GridView -Title "select cluster to reboot sequentially" -OutputMode Single

RestartCluster -cluster $cluster
