#!/usr/bin/env bash

#                                                                  Printing Basic Subjob Information
####################################################################################################################################################################

echo
echo "                                                  *** Job Information ***                                                        "
echo "*********************************************************************************************************************************"
echo
echo "Environment variables"
echo "------------------------"
env
echo
echo


#                                                                           Basic Setup
####################################################################################################################################################################

# Shell options
set -m                  # Allowing each task to be in its own process group (HQ assumes that, though it will check and work around if this should not be the case)

# Verbosity
HQ_VERBOSITY="$(grep -m 1 "^verbosity=" input-files/config.txt | awk -F '=' '{print $2}' | tr -d '[:space:]')"
export HQ_VERBOSITY
if [ "${HQ_VERBOSITY}" = "debug" ]; then
    set -x
fi


#                                                                         Running the tasks
#####################################################################################################################################################################

# List of tasks
#task_placeholder

# Waiting for the tasks to complete
wait
