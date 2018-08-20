function Get-Audit () {

    # UPDATE: We'll use $SitecoreLogFolder instead. SPE creates a variable $SitecoreLogFolder and resolves the path for you.
    # Identify the Sitecore log folder
    # $logsFolder = [Sitecore.Configuration.Settings]::LogFolder
    # Resolve the log folder's path
    # $resolvedPath = Resolve-Path -Path $logsFolder
    
    # Get all log files, then filter out everything that doesn't matter. Sort by LastWriteTime descending. 
    $files = Get-ChildItem $SitecoreLogFolder | Where-Object {  $_.Name -notmatch "Fxm" -and $_.Name -NotMatch "Search" -and $_.Name -NotMatch "WebDAV" -and $_.Name -NotMatch "client" -and $_.Name -NotMatch "Crawling" -and $_.Name -NotMatch "Publishing" -and $_.Name -NotMatch "spe" -and $_.Name -NotMatch "custom"  } | Sort-Object LastWriteTime -Descending 
    
    # Confirm the user has provided start and end dates. 
    if ($selectedEndDate -ne "01/01/0001 00:00:00" -and $selectedStartDate.Year -ne "01/01/0001 00:00:00") {
        
        # Filter the log files further to only those within range.
        $filteredFiles = $files | Where-Object {$_.LastWriteTime -ge $selectedEndDate -and $_.LastWriteTime -le $selectedStartDate  } 
        
    }
    else {
        
        # If a user chose to not select a date range, use the original file list, but limit the process to the most recent 25 files.
        $filteredFiles = $files | Select-Object -First 5
        
    }
    
    # Define a variable used to match the term 'Audit' when processing each line.
    $regex = " audit "

    # Define an array to house matching line objects.
    $finalItems = @()
    
    # Begin a loop based on the number of files to process.
    for ($i = 0; $i -lt $filteredFiles.Count; $i++) {
        
        # Get the content of the file.
        $fileContent = Get-Content $filteredFiles[$i].FullName
        
        # Set the current file
        $file = $filteredFiles[$i]
        
        # Create a date string based on the LastAccessTime.
        $formattedFileDate = "$($file.LastAccessTime.Date.Month)/$($file.LastAccessTime.Date.Day)/$($file.LastAccessTime.Date.Year)"
        
        # Loop through each line in the file.
        foreach ($line in $fileContent) {
            # Check of the line matches the 'AUDIT' regular expression.
            if ($line -match $regex) {
                # Concatenate the date and the rest of the line to a single variable.
                $logLine = "$formattedFileDate $line"
                
                # Remove double spaces from the line.
                $saitizedLogLine = $logLine.Replace("  ", " ")

                # In some cases, the audit line will contain ManagedPoolThread #XX instead of an ID.  This accounts for this scenario
                $saitizedLogLine = $saitizedLogLine -Replace "(((ManagedPoolThread)\s\#[^\s]+)\s)", "0 "
                
                # Split the line by spaces and create new objects for each property.
                $date, $apid, $time, $loglevel, $logcode, $username, $action = $saitizedLogLine.split(" ")
                
                # Sanitize the username object (removing '{', '}', and ":" characters).
                $username = $username -Replace "[#?\{\[\(\)\]\}\:]", ""
                
                # Concatenate the date and time objects to a single string.
                $dateTime = "$date $time"
                
                # Convert the concatenated dateTime string to a System.DateTime.
                $dateObj = [datetime]($dateTime)

                # Define a new line object with each object.
                $lineObj = [pscustomobject]@{date = $dateTime; pid = $apid; time = $time; loglevel = $loglevel; logcode = $logcode; username = $username; action = $action; logLine = $logLine; dateObj = $dateObj; }
                
                # Add the line object to the finalItems array.
                $finalItems += $lineObj
            }
        }
    }
    # Return the finalItems array sorted by date/time descending.
    $finalItems | Sort-Object { $_.dateObj -as [datetime]} -Descending 
}

# Define the dialog properties.  We'll need a start date and end date input from the user.
$dialogProps = @{
    Parameters  = @(
        @{Name = "selectedStartDate"; Title = "Closest Date"; Editor = "date time"; Tooltip = "(How recent?)"},
        @{Name = "selectedEndDate"; Title = "Furthest Date"; Editor = "date time"; Tooltip = "(How far back?)"}
    )
    Title       = "Date Filter"
    Description = "Select a date range to filter the audit."
    ShowHints   = $true
}

# Invoke the dialog and set the Read-Variable to determine if the user selects 'cancel'.
$datemodal = Read-Variable @dialogProps

# Check if the user clicked 'cancel.
if ($datemodal -ne "cancel") {
    # Define the ListView properties. 
    $tableProps = @{
        InfoTitle       = "Audit Trail Report"
        InfoDescription = "Audit user logins, logouts, workflow executions, and publishing operations within a specified date range."
        PageSize        = 100
    }

    # Get and display the report in a ListView. 
    Get-Audit | Show-ListView @tableProps -Property @{ Label = "Date"; Expression = { $_.date } },
    @{ Label = "ID"; Expression = { $_.pid } },
    @{ Label = "Level"; Expression = { $_.loglevel } },
    @{ Label = "Code"; Expression = { $_.logcode } },
    @{ Label = "User"; Expression = { $_.username } },
    @{ Label = "Action"; Expression = { $_.action } }
    
    Close-Window 
}