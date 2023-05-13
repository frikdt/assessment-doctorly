incrementNpmVersion() {

    printf "%s\t\n" "Calculating next version for ${package_name}:"

    # Get the latest version number for the given stream
    printf "\t%s\n" "Searching for existing versions..."
    local newest_npm_version=$(npm view @gitlab-doctorly-demo/${package_name} versions --registry ${npm_reg} --json | \
        jq -r 'map(select(. | contains('\"${stream}\"'))) | max_by(.)')
 
    # Default version to "0.0.0" if none is found
    if [[ "${newest_npm_version}" == "null" ]]
    then
        newest_npm_version=0.0.0
        printf "\t%s\t%s\n" "None found, default:" "${newest_npm_version}"
    elif [[ -z "${newest_npm_version}" ]]
    then
        newest_npm_version=0.0.0
        printf "\t%s\t%s\n" "None found, default:" "${newest_npm_version}"
    else
        printf "\t%s\t%s\n" "Newest version found:" "${newest_npm_version}"
    fi

    # Get YML Major and Minor changes
    local declare yml_major
    local declare yml_minor
    getYmlVersion yml_major yml_minor

    # Determine new version number
    local declare next_version
    calcNewVersion ${yml_major} ${yml_minor} ${newest_npm_version} next_version

    # Version to publish
    version="${next_version}-${stream}-${pipleine_hash}"
    printf "\t%s\t\t%s\n" "Next version:" "${version}"

    # Update package.json version
    npm version ${version}
}

incrementContainerVersion() {
       
    local api_repository=${stream}/${container_name}
    printf "%s\t%s\n" "Calculating next version for ${api_repository}:"

    #-- Get newest container version
    # Get repo id
    local repo_id=$(curl --header "PRIVATE-TOKEN: ${gitlab_api_token}" "${container_reg}" | \
        jq '.[] | select(.name | contains('\"${api_repository}\"')) | .id'
    )
    # get newest image in repo
    local newest_container_version=$(curl --header "PRIVATE-TOKEN: ${gitlab_api_token}" "${container_reg}${repo_id}/tags" | \
        jq -r 'map(select(.name)) | max_by(.) | .name'
    )
    #-- Default version to "0.0.0" if none is found
    if [[ "${newest_container_version}" == "null" ]]
    then
        newest_container_version=0.0.0
        printf "\t%s\t%s\n" "None found, default:" "${newest_container_version}"
    elif [[ -z "${newest_container_version}" ]]
    then
        newest_container_version=0.0.0
        printf "\t%s\t%s\n" "None found, default:" "${newest_container_version}"
    else
        printf "\t%s\t%s\n" "Newest version found:" "${newest_container_version}"
    fi

    #-- Get YML Major and Minor changes
    local declare yml_major
    local declare yml_minor
    getYmlVersion yml_major yml_minor

    #-- Determine new version number
    local declare next_version
    calcNewVersion ${yml_major} ${yml_minor} ${newest_container_version} next_version

    # Version to publish
    version="${next_version}-${stream}-${pipleine_hash}"
    printf "\t%s\t\t%s\n" "Next version:" "${version}"

    #-- Update package.json version
    # This version will be used to tag the container as well
    npm version ${version}
}

getYmlVersion() {
    declare -n major=${1}
    declare -n minor=${2}

    # Check if YML versions exist
    if [ -z "${yml_major}" ]
    then
        printf "\t%s\n" "Error: 'versioning.major' not found"
        exit 1
    elif [ -z "${yml_minor}" ]
    then
        printf "\t%s\n" "Error: 'versioning.minor' not found"
        exit 1
    fi
}

calcNewVersion() {

    local yml_major=${1}
    local yml_minor=${2}
    local current_version=${3}

    declare -n new_version=${4}

    # Remove "-<stream>"
    local current_version=$(echo ${current_version} | sed -E "s/-.*//")

    # Split the version number into an array
    local a_current_version=( $(sed -E "s/([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)/\1 \2 \3/"<<<${current_version}) )

    # Check if YML versions are out of date
    if (( ${yml_major} < ${a_current_version[0]} ))
    then
        printf "\t%s\n" "Error: yml_major version is older than the currently published version"
        exit 1
    elif (( ${yml_major} == ${a_current_version[0]} && ${yml_minor} < ${a_current_version[1]} ))
    then
        printf "\t%s\n" "Error: yml_minor version is older than the currently published version"
        exit 1
    fi

    # Determine new version number for deploy
    if (( ${yml_major} > ${a_current_version[0]} ))
    then
        new_version="${yml_major}.${yml_minor}.0"
    elif (( ${yml_minor} > ${a_current_version[1]} ))
    then
        new_version="${a_current_version[0]}.${yml_minor}.0"
    else
        new_version=${a_current_version[0]}.${a_current_version[1]}.$((${a_current_version[2]} + 1))
    fi
}

target=${1}
case ${target} in
    package )
        package_name=${2}
        stream=${3}
        pipleine_hash=${4}
        npm_reg=${5}

        incrementNpmVersion 
        ;;
    api )
        container_name=${2}
        stream=${3}
        pipleine_hash=${4}
        container_reg=${5}
        gitlab_api_token=${6}

        incrementContainerVersion
        ;;
esac
