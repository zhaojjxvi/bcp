#retrieve parameter for $UserID_or_Accout
Param(
    [string]
    $UserID_or_Accout = 0
)

while (($UserID_or_Accout -ne 1) -and ($UserID_or_Accout -ne 2)) {
    $UserID_or_Accout = Read-Host -Prompt "Please choose to login to DB server with (1 or 2):`n [1]UserID`n [2]Account" 
}

if ($UserID_or_Accout -eq 2) {
    $Account = Read-Host -Prompt "Please enter the Generic Account name?"
    $Passwd = Read-Host -Prompt "Please enter the password?" #-AsSecureString #Commented due to sqlcmd error for SecureString
}

Clear-Host

$CSV = import-Csv ".\Import_list.csv"
$log_file = ".\log.txt"
$prompt_log = ".\cmd.log"
$i=1
"###Start Batch Export/Import on $(get-date) ###" >> $log_file
foreach ($item in $CSV){
    $Source_Query = $item.Source_Query
    $Data_File = $item.Data_File
    $Source_Server = $item.Source_Server
    $Source_DB = $item.Source_DB
    $Des_Server = $item.Des_Server
    $Des_DB =  $item.Des_DB
    $Des_Table = $item.Des_Table
    $Flag = $item.Flag

    if ($Flag -eq 0) {
        "$i of $($CSV.count) tasks `r  skipped (Flag set 0)" >> $log_file
        "$i of $($CSV.count) tasks skipped"
        $i++
        continue
    }

    # export data
    #$bcp_queryout_string
    if ($UserID_or_Accout -eq 1) {
        $bcp_queryout_string = "bcp ""$Source_Query"" queryout $Data_File -S $Source_Server -d $Source_DB -T -b100000 -""t|||"" -c -C 65001"
    }
    else {
        $bcp_queryout_string = "bcp ""$Source_Query"" queryout $Data_File -S $Source_Server -d $Source_DB -T -b100000 -""t|||"" -c -C 65001 -U $Account -P $Passwd"
    }

    "$i of $($CSV.count) tasks `r  Source SQL: $Source_Query`r  Export`r    Start: $(get-date)" >> $log_file
    Write-Host "$i of $($CSV.count) tasks committing..." -NoNewline

    Invoke-expression $bcp_queryout_string > $prompt_log

    "      " + (select-string -path $prompt_log -pattern 'rows copied')[0].line + "`r    End:   $(get-date)" >> $log_file

    # truncate destination table
    "  Destination Table: $Des_Table`r  Truncate`r    Start: $(get-date)" >> $log_file

    #$sqlcmd_truncate_string
    if ($UserID_or_Accout -eq 1) {
        $sqlcmd_truncate_string = "sqlcmd -S $Des_Server -d $Des_DB -C -E -Q ""truncate table $Des_Table"""
    }
    else {
        $sqlcmd_truncate_string = "sqlcmd -S $Des_Server -d $Des_DB -C -Q ""truncate table $Des_Table"" -U $Account -P $Passwd"
    }
    
    Invoke-expression $sqlcmd_truncate_string

    "    End:   $(get-date)" >> $log_file

    # import data
    #$bcp_in_string
    if ($UserID_or_Accout -eq 1) {
        $bcp_in_string = "bcp ""$Des_Table"" in $Data_File -S $Des_Server -d $Des_DB -T -b100000 -""t|||"" -c -C 65001"
    }
    else {
        $bcp_in_string = "bcp ""$Des_Table"" in $Data_File -S $Des_Server -d $Des_DB -T -b100000 -""t|||"" -c -C 65001 -U $Account -P $Passwd"
    }
    
    "  Import`r    Start: $(get-date)" |Out-File  -append -filepath $log_file

    Invoke-expression $bcp_in_string > $prompt_log

    "      " + (select-string -path $prompt_log -pattern 'rows copied')[0].line + "`r    End:   $(get-date)" >> $log_file
    Write-Host "done"

    # remove temp data file
    Remove-Item $prompt_log
    Remove-Item $Data_File
    
    $i++
}
"###End Batch Export/Import on $(get-date) ###`r" >> $log_file