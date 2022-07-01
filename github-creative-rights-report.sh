#!/bin/bash
set -u 
#----- USER CONFIGURABLE VARIABLES - BEGINING ---------
# Set cloning directory within user's home directory
GITHUB_CLONE_DIR="${HOME}/github.com"
#----- USER CONFIGURABLE VARIABLES - END---------------

FIRST_DAY_OF_MONTH="1.months.ago"
#$(date +%Y-%m-01)
month=$(date +%B)
echo "Generating Creative Rights Report for current month: $month"

REPORTS_DIR="$HOME/Creative Rights Reporting"
if [ ! -d "$REPORTS_DIR/$month" ]; then
    mkdir -p "$REPORTS_DIR/$month"
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
        if [ ! -d "$REPORTS_DIR/$month/$githubhandle" ]; then
            mkdir -p "$REPORTS_DIR/$month/$githubhandle"
        fi
        git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_MONTH --until="today" > "$REPORTS_DIR/$month/$githubhandle/$reponame-creative-rights-report-$month.txt"
        [ -s "$REPORTS_DIR/$month/$githubhandle/$reponame-creative-rights-report-$month.txt" ] && echo "Saved report" || (echo "No commits by $githubhandle in $reponame"; rm "$REPORTS_DIR/$month/$githubhandle/$reponame-creative-rights-report-$month.txt")
        cd - || exit
    else
        gh repo clone "$repo" "$repo" 
        # --mirror #(add "--mirror" to command to have all the branches cloned locally)
        cd "$repo" || exit
        reponame=$(basename `pwd`)
        git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_MONTH --until="today" > "$REPORTS_DIR/$month/$githubhandle/$reponame-creative-rights-report-$month.txt"
        [ -s "$REPORTS_DIR/$month/$githubhandle/$reponame-creative-rights-report-$month.txt" ] && echo "Saved report" || (echo "No commits by $githubhandle in $reponame"; rm "$REPORTS_DIR/$month/$githubhandle/$reponame-creative-rights-report-$month.txt")
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
            reponame=${repo/\//-}
            if [ ! -d "$REPORTS_DIR/$month/organisations" ]; then
                mkdir -p "$REPORTS_DIR/$month/organisations"
            fi
            git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_MONTH --until="today" > "$REPORTS_DIR/$month/organisations/$reponame-creative-rights-report-$month.txt"
            [ -s "$REPORTS_DIR/$month/organisations/$reponame-creative-rights-report-$month.txt" ] && echo "Saved report" || echo "No commits by $githubhandle in $reponame" && rm "$REPORTS_DIR/$month/organisations/$reponame-creative-rights-report-$month.txt"
            cd - || exit
        else
            gh repo clone "$repo" "$repo" 
            # --mirror #(add "--mirror" to command to have all the branches cloned locally)
            cd "$repo" || exit
            reponame=${repo/\//-}
            if [ ! -d "$REPORTS_DIR/$month/organisations" ]; then
                mkdir -p "$REPORTS_DIR/$month/organisations"
            fi
            git log --branches --author="$githubhandle" --pretty=format:"%h%x09%an%x09%ad%x09%s" --since=$FIRST_DAY_OF_MONTH --until="today" > "$REPORTS_DIR/$month/organisations/$reponame-creative-rights-report-$month.txt"
            [ -s "$REPORTS_DIR/$month/organisations/$reponame-creative-rights-report-$month.txt" ] && echo "Saved report" || echo "No commits by $githubhandle in $reponame" && rm "$REPORTS_DIR/$month/organisations/$reponame-creative-rights-report-$month.txt"
        fi
    done
done
