#!/bin/bash

function terraformPlan {
  # Gather the output of `terraform plan`.
  echo "plan: info: planning Terraform configuration in ${tfWorkingDir}"
  planOutput=$(terraform plan -detailed-exitcode -input=false ${*} 2>&1)
  planExitCode=${?}
  planHasChanges=false
  planCommentStatus="Failed"
  planOutputFile="${GITHUB_WORKSPACE}/${tfWorkingDir}/plan.txt"
  touch "${planOutputFile}"
  echo "::set-output name=tf_actions_plan_output_file::${planOutputFile}"

  # Save full plan output to a file so it can optionally be added as an artifact
  # Save the un-truncated output
  echo "${planOutput}" > "${planOutputFile}"

  # If output is longer than max length (65536 characters), keep last part
  planOutput=$(echo "${planOutput}" | tail -c 65000 )

  # Exit code of 0 indicates success with no changes.
  if [ ${planExitCode} -eq 0 ]; then
    planCommentStatus="NoChanges"
    echo "plan: info: successfully planned Terraform configuration in ${tfWorkingDir}"
    echo "${planOutput}"
    echo
    echo ::set-output name=tf_actions_plan_has_changes::${planHasChanges}
  fi

  # Exit code of 2 indicates success with changes. Print the output, change the
  # exit code to 0, and mark that the plan has changes.
  if [ ${planExitCode} -eq 2 ]; then
    planExitCode=0
    planHasChanges=true
    planCommentStatus="Success"
    echo "plan: info: successfully planned Terraform configuration in ${tfWorkingDir}"
    echo "${planOutput}"
    echo
    
  fi

  # Exit code of !0 indicates failure.
  if [ ${planExitCode} -ne 0 ]; then
    planCommentStatus="Failure"
    echo "plan: error: failed to plan Terraform configuration in ${tfWorkingDir}"
    echo "${planOutput}"
    echo
  fi

  # Comment on the pull request if necessary.
  if [ "${tfComment}" == "1" ] && [ -n "${tfCommentUrl}" ]; then
    planCommentWrapper="#### \`terraform plan\` ${planCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${planOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tfWorkingDir}\`, Workspace: \`${tfWorkspace}\`*"

    planCommentWrapper=$(stripColors "${planCommentWrapper}")
    echo "plan: info: creating JSON"
    planPayload=$(echo "${planCommentWrapper}" | jq -R --slurp '{body: .}')
    echo "plan: info: commenting on the pull request"
    echo "${planPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${tfCommentUrl}" > /dev/null
  fi

  echo ::set-output name=tf_actions_plan_has_changes::${planHasChanges}

  # https://github.community/t5/GitHub-Actions/set-output-Truncates-Multiline-Strings/m-p/38372/highlight/true#M3322
  planOutput="${planOutput//'%'/'%25'}"
  planOutput="${planOutput//$'\n'/'%0A'}"
  planOutput="${planOutput//$'\r'/'%0D'}"

  echo "::set-output name=tf_actions_plan_output::${planOutput}"
  exit ${planExitCode}
}
