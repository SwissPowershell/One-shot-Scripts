Function Get-LMStudioAnswer {
    [CMDLetBinding()]
    Param(
        [String] ${BaseUrl},
        [String] ${Model},
        [String] ${Query}
    )
    $ModelString = $Model -replace '/','-'
    $Uri = "$($BaseUrl)/v1/chat/completions"
    $Headers = @{
        'Content-Type' = 'application/json'
    }
    $Body = @{
        model = $ModelString
        messages = @(
            @{
                role = 'user'
                content = $Query
            }
        )
        temperature = 0.7

    } | ConvertTo-Json -Depth 3

    $WebRequestResult = Invoke-WebRequest -Uri $Uri -Method 'POST' -Headers $Headers -Body $Body
    $Content = $WebRequestResult | Select-Object -ExpandProperty 'Content' | ConvertFrom-Json -Depth 6
    $Result = $Content.choices.Message.Content
    return $Result
}
# check prerequisite
# check LM Studio is installed and running
Write-Host "Checking LM Studio" -ForegroundColor Yellow
$LMStudioOK = $false
$LMStudio = Try {lms --help}Catch{}
if ($LMStudio) {
    $LMStudioStatusResult = Try {lms status}Catch{}
    if ($LMStudioStatusResult) {
        $FirstLine = $LMStudioStatusResult[0]
        $RegexResult = $FirstLine | Select-String -Pattern '^Server:\s(?<Status>ON|OFF)\s\(port:\s(?<Port>1234)\)$'
        $LMStudioStatus = ($RegexResult.matches.Groups | Where-Object {$_.Name -eq 'status'} | Select-Object -ExpandProperty Value) -eq 'ON'
        [int32] $LMStudioPort = $RegexResult.matches.Groups | Where-Object {$_.Name -eq 'port'} | Select-Object -ExpandProperty Value
        if (($LMStudioStatus -eq $true) -and ($LMStudioPort -gt -1)) {
            Write-Host "`t LM Studio is running on port '$($LMStudioPort)'" -ForegroundColor Green
            $LMStudioOK = $true
        }
    }
}
if ($LMStudioOK -eq $false) {
    Throw 'LM Studio is not correctly configured please review...'
}Else{
    $LMStudioBaseURL = "http://localhost:$($LMStudioPort)"
    # Getting Models
    Write-Host 'LM Studio model list' -ForegroundColor Yellow
    $ModelList = Invoke-WebRequest -Uri "$($LMStudioBaseURL)/v1/models" -ErrorAction 'STOP' | Select-Object -ExpandProperty 'Content' | convertFrom-Json -Depth 200 | Select-Object -ExpandProperty 'Data' | where-Object {$_.Object -eq 'model'}
    $ExcludeModel = @('text-embedding-nomic-embed-text-v1.5')
    $ModelList = $ModelList | Where-Object {$_.Id -notin $ExcludeModel}
    ForEach ($Model in $ModelList) {
        Write-Host "`t - $($Model.id)" -ForegroundColor Green
    }
    $Query = 'Hello who are you ?'
    Write-Host "Test basic chat against each of the available model (Q: $($Query))" -ForegroundColor Yellow
    ForEach($Model in $ModelList) {
        Write-Host "Model: $($Model.id) Input: $($Query)" -ForegroundColor Yellow
        $Answer = Get-LMStudioAnswer -BaseUrl $LMStudioBaseURL -Model $Model.id -Query $Query
        Write-Host $Answer
    }
}   