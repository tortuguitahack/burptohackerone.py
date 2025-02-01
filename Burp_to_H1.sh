#!/bin/bash

# Setup logging
LOGFILE="script.log"
exec > >(tee -a "$LOGFILE") 2>&1
exec 2> >(tee -a "$LOGFILE" >&2)

log_message() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$LOGFILE"
}

extract_report_from_html() {
    local html_file="$1"
    local title findings
    title=$(grep -oP '(?<=<title>).*?(?=</title>)' "$html_file" || echo "Untitled Report")
    findings=$(grep -oP '(?<=<div class="issue">).*?(?=</div>)' "$html_file" | sed -e 's/<[^>]*>//g')

    local reports=()
    while IFS= read -r finding; do
        local issue_name description request response impact
        issue_name=$(echo "$finding" | grep -oP '(?<=<h2>).*?(?=</h2>)' || echo "Unnamed Issue")
        description=$(echo "$finding" | grep -oP '(?<=<div class="issue-description">).*?(?=</div>)' || echo "No description provided.")
        request=$(echo "$finding" | grep -oP '(?<=<pre class="request">).*?(?=</pre>)' || echo "No request captured.")
        response=$(echo "$finding" | grep -oP '(?<=<pre class="response">).*?(?=</pre>)' || echo "No response captured.")
        impact=$(echo "$finding" | grep -oP '(?<=<div class="issue-impact">).*?(?=</div>)' || echo "No impact information provided.")

        reports+=("Title: $issue_name
Description: $description
Impact: $impact
Request: $request
Response: $response
")
    done <<< "$findings"

    echo "${reports[@]}"
}

generate_hackerone_report() {
    local report="$1"
    local output_folder="$2"
    local title description impact request response

    title=$(echo "$report" | grep -oP '(?<=Title: ).*')
    description=$(echo "$report" | grep -oP '(?<=Description: ).*')
    impact=$(echo "$report" | grep -oP '(?<=Impact: ).*')
    request=$(echo "$report" | grep -oP '(?<=Request: ).*')
    response=$(echo "$report" | grep -oP '(?<=Response: ).*')

    local template
    template=$(cat <<EOF
Title: $title

Description:
$description

Impact:
$impact

Steps to Reproduce:
1. Send the following HTTP request:

Request:
$request

2. Observe the response:

Response:
$response

Mitigation:
Provide detailed information about how to fix the issue.
EOF
)
    local report_filename
    report_filename="${output_folder}/$(echo "$title" | tr -cd '[:alnum:]').txt"
    echo "$template" > "$report_filename"
    log_message "Generated report: $report_filename"
}

process_burp_report() {
    local html_file="$1"
    local output_folder="$2"
    local reports
    reports=$(extract_report_from_html "$html_file")
    IFS=$'\n'
    for report in $reports; do
        generate_hackerone_report "$report" "$output_folder"
    done
}

process_burp_reports() {
    local input_folder="$1"
    local output_folder="$2"
    mkdir -p "$output_folder"
    local html_files
    html_files=$(find "$input_folder" -name '*.html')
    if [ -z "$html_files" ]; then
        log_message "No HTML files found in the input folder."
        return
    fi
    log_message "Processing $(echo "$html_files" | wc -l) report(s)..."
    for html_file in $html_files; do
        log_message "Processing $html_file..."
        process_burp_report "$html_file" "$output_folder" &
    done
    wait
    log_message "Report processing completed."
    notify_user
}

notify_user() {
    # Implement notification logic here (e.g., send an email or a message)
    log_message "User notified of completion."
}

# Example usage
input_folder="burp_reports"  # Folder containing Burp Suite HTML reports
output_folder="hackerone_reports"  # Folder to save the HackerOne-compatible reports

process_burp_reports "$input_folder" "$output_folder"
