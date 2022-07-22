#!/bin/bash
set -u 
#----- USER CONFIGURABLE VARIABLES - BEGINING ---------
# Set cloning directory within user's home directory
GITHUB_CLONE_DIR="${HOME}/github.com"
TIMEZONE="Europe/Warsaw"
#----- USER CONFIGURABLE VARIABLES - END---------------

# Get todays day with assumption it is exactly 1st day of next month (we use to do reporting until 5th of next month)
# We need to easly make it work on both GNU 'date' and BSD (ie. Macs) 'date' utility so we use the simplest 
# syntax for date command possible and do an exception for January
# The timezone is set above, defaults to Europe/Warsaw, as this is needed for Polish tax incentive accounting
# - this is needed to have it working properly with ie. github actions
export TZ="${TIMEZONE}"
THIS_MONTH_NUMBER=$(date +%m)
THIS_YEAR=$(date +%Y)
if [ "$THIS_MONTH_NUMBER" -ne "01" ]; then
    REPORTED_MONTH_NUMBER=$(printf "%02d" $(($THIS_MONTH_NUMBER - 1 )) )
    REPORTED_YEAR=$THIS_YEAR
    else
    REPORTED_MONTH_NUMBER=12 # set to December
    REPORTED_YEAR=$((THIS_YEAR=$THIS_YEAR-1)) || true
fi
REPORTED_MONTH="$REPORTED_YEAR-$REPORTED_MONTH_NUMBER"
FIRST_DAY_OF_REPORTED_MONTH="$REPORTED_MONTH-01"
# Get last day of previous month using either GNU date or BSD (Mac) date
# (BSD version of 'date' doesn't work with '--version' option)
if date --version >/dev/null 2>&1 ; then
    LAST_DAY_OF_REPORTED_MONTH=$(date -d "$(date +%Y-%m-01) -1 day" +%d)
    else
    LAST_DAY_OF_REPORTED_MONTH=$(date -v-1d +%d)
fi
LAST_DAY_OF_REPORTED_MONTH="$REPORTED_YEAR-$REPORTED_MONTH_NUMBER-$LAST_DAY_OF_REPORTED_MONTH"

echo "Generating Creative Rights Report for: $REPORTED_MONTH"

REPORTS_DIR="$GITHUB_CLONE_DIR/Creative Rights Reporting"
if [ ! -d "$REPORTS_DIR/$REPORTED_MONTH" ]; then
    mkdir -p "$REPORTS_DIR/$REPORTED_MONTH"
fi

# Github CLI is used, check if installed
if ! type gh 1> /dev/null; then
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
   
    if ! gh auth status; then
        echo -e "\nGithub CLI is not authenticated yet, proceed with on screen steps:\n"
        gh auth login
    else    
        echo -e "\nGithub login succesful\n"
        ((auth_tries=4))
        continue
    fi
    ((auth_tries++))
done    

githubhandle=$(cat ~/.config/gh/hosts.yml|grep user|awk '{print $2}') || exit

# Cycle through personal repositories (by GH handle)
mkdir -p "${GITHUB_CLONE_DIR}"
cd "${GITHUB_CLONE_DIR}" || exit
gh repo list "${githubhandle}" --limit 1000 | while read -r repo _; do
    # And clone the repos one by one (if the repo exists try to fetch instead of cloning)
    if [ -d "$repo" ]; then
        echo "$repo already cloned, fetching changes..."
        cd "$repo" || exit
        git fetch
        reponame=$(basename `pwd`)
        if [ ! -d "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle" ]; then
            mkdir -p "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle"
        fi
        git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_REPORTED_MONTH --until="yesterday" > "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle/$reponame-creative-rights-report-$REPORTED_MONTH.txt"
        [ -s "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle/$reponame-creative-rights-report-$REPORTED_MONTH.txt" ] && echo "Saved report" || (echo "No commits by $githubhandle in $reponame"; rm "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle/$reponame-creative-rights-report-$REPORTED_MONTH.txt")
        cd - || exit
    else
        gh repo clone "$repo" "$repo" 
        # --mirror #(add "--mirror" to command to have all the branches cloned locally)
        cd "$repo" || exit
        reponame=$(basename `pwd`)
        git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_REPORTED_MONTH --until="yesterday" > "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle/$reponame-creative-rights-report-$REPORTED_MONTH.txt"
        [ -s "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle/$reponame-creative-rights-report-$REPORTED_MONTH.txt" ] && echo "Saved report" || (echo "No commits by $githubhandle in $reponame" ; rm "$REPORTS_DIR/$REPORTED_MONTH/$githubhandle/$reponame-creative-rights-report-$REPORTED_MONTH.txt")
    fi
done

GH_ORGANISATION_LIST=""
# If there's no manual input then just get all of user's organisations repositories
if [ -z "$GH_ORGANISATION_LIST" ]; then
    # Get Github orgranisations list user belongs to
    GH_ORGANISATION_LIST=$( gh api  /user/memberships/orgs  --jq '.[].organization.login' )
fi

# Output variables which were set above
echo -e "\nGithub organisations list:\n----------------------------\n${GH_ORGANISATION_LIST}\n----------------------------"
echo -e "\nLocal cloning directory:\n----------------------------\n ${GITHUB_CLONE_DIR}/organisations\n----------------------------"

# Cycle through the list and clone all repositories from all organisations (only main/master branch, unless --mirror option added)
for GH_ORGANISATION in $GH_ORGANISATION_LIST; do
    # Create an organisation directory
    mkdir -p "${GITHUB_CLONE_DIR}/organisations"
    cd "${GITHUB_CLONE_DIR}/organisations" || exit
    # Using github cli get repositories list from processed organisation
    gh repo list "${GH_ORGANISATION}" --limit 1000 | while read -r repo _; do
        # And clone the repos one by one (if the repo exists try to fetch instead of cloning)
        if [ -d "$repo" ]; then
            echo "$repo already cloned, fetching changes..."
            cd "$repo" || exit
            git fetch
            # Replace '/' with '-' for 'reponame' from 'repo' which is a path essentially 
            reponame=${repo/\//-}
            if [ ! -d "$REPORTS_DIR/$REPORTED_MONTH/organisations" ]; then
                mkdir -p "$REPORTS_DIR/$REPORTED_MONTH/organisations"
            fi
            git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_REPORTED_MONTH --until=$LAST_DAY_OF_REPORTED_MONTH > "$REPORTS_DIR/$REPORTED_MONTH/organisations/$reponame-creative-rights-report-$REPORTED_MONTH.txt"
            [ -s "$REPORTS_DIR/$REPORTED_MONTH/organisations/$reponame-creative-rights-report-$REPORTED_MONTH.txt" ] && echo "Saved report" || (echo "No commits by $githubhandle in $reponame"; rm "$REPORTS_DIR/$REPORTED_MONTH/organisations/$reponame-creative-rights-report-$REPORTED_MONTH.txt")
            cd - || exit
        else
            gh repo clone "$repo" "$repo" 
            # --mirror #(add "--mirror" to command to have all the branches cloned locally)
            cd "$repo" || exit
            reponame=${repo/\//-}
            if [ ! -d "$REPORTS_DIR/$REPORTED_MONTH/organisations" ]; then
                mkdir -p "$REPORTS_DIR/$REPORTED_MONTH/organisations"
            fi
            git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_REPORTED_MONTH --until=$LAST_DAY_OF_REPORTED_MONTH > "$REPORTS_DIR/$REPORTED_MONTH/organisations/$reponame-creative-rights-report-$REPORTED_MONTH.txt"
            [ -s "$REPORTS_DIR/$REPORTED_MONTH/organisations/$reponame-creative-rights-report-$REPORTED_MONTH.txt" ] && echo "Saved report" || (echo "No commits by $githubhandle in $reponame"; rm "$REPORTS_DIR/$REPORTED_MONTH/organisations/$reponame-creative-rights-report-$REPORTED_MONTH.txt")
        fi
    done
done
