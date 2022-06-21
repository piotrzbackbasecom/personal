#!/bin/bash
set -u 

#----- USER CONFIGURABLE VARIABLES - BEGINING ---------
# Set cloning directory within user's home directory
GITHUB_CLONE_DIR="${HOME}/github.com/organisations"
#----- USER CONFIGURABLE VARIABLES - END---------------

# Github CLI is used, check if installed
which gh
if [ $? -ne 0 ]; then
    echo "Github CLI is needed, install using manuals first:
        MacOS/Windows: https://github.com/cli/cli#installation
        Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    exit 1
fi

# Check Github authentication status for current user (3 times)
auth_tries=0
until [ $auth_tries -gt 3 ]; do
    if [ $auth_tries -eq 3 ]; then
        echo -e "\nGithub authentication failed, terminating...\n"
        exit 2
    fi
   gh auth status
    if [ $? -ne 0 ]; then
        echo -e "\nGithub CLI is not authenticated yet, proceed with on screen steps:\n"
        gh auth login
    else    
        echo "\nGithub login succesful\n"
        ((auth_tries=4))
        continue
    fi
    ((auth_tries++))
done    


# Get list of organisations from parameters put into commandline
GH_ORGANISATION_LIST="$@"

# If there's no manual input then just get all of user's organisations repositories
if [ -z "$GH_ORGANISATION_LIST" ]; then
    # Get Github orgranisations list user belongs to
    GH_ORGANISATION_LIST=$( gh api  /user/memberships/orgs  --jq '.[].organization.login' )
fi

# Output variables which were set above
echo -e "\nGithub organisations list:\n----------------------------\n${GH_ORGANISATION_LIST}\n----------------------------"
echo -e "\nLocal cloning directory:\n----------------------------\n ${GITHUB_CLONE_DIR}\n----------------------------"

# Cycle through the list and clone all repositories from all organisations (only main/master branch, unless --mirror option added)
for GH_ORGANISATION in $GH_ORGANISATION_LIST; do
    # Create an organisation directory
    mkdir -p ${GITHUB_CLONE_DIR}
    cd ${GITHUB_CLONE_DIR}
    # Using github cli get repositories list from processed organisation
    gh repo list ${GH_ORGANISATION} --limit 1000 | while read -r repo _; do
        # And clone the repos one by one (if the repo exists try to fetch instead of cloning)
        if [ -d "$repo" ]; then
            echo "$repo already cloned, fetching changes..."
            cd $repo
            git fetch
            cd -
        else
            gh repo clone "$repo" "$repo" 
        # --mirror #(add "--mirror" to command to have all the branches cloned locally)
        fi
    done
done
