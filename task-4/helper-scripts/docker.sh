#!/bin/sh

###
# This is a code example showing how to use getops to parse short options and a
# subcommand with short options of it's own. Based on Kevin Sookocheff's post:
# https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/
# 
# Please feel free to use it and modify it as you see fit. Any questions and/or
# recommendations are more than welcome.
###

# get the scripts name for the usage message
_filename=$(basename $0)

# verbose mode deactivated
verbose=false

SCRIPT_DIR="$(dirname "${0}")"
if $(test -h /bin/ls); then
  # This is probably busybox
  PROJECT_ROOT=$(realpath "$SCRIPT_DIR/../..")
else
  PROJECT_ROOT="/"$(realpath --relative-to="/" "$SCRIPT_DIR/../..")
fi
. "$SCRIPT_DIR/../colors.sh"

if [ -z "$CI" ]; then
  echo -e "${BRed}[ERROR]${Color_Off} Using this script in a non-CI environent is not recommended"
  exit 1
fi

# argument variables
container=""
source=""

if test "${CI_COMMIT_BRANCH#*rel-}" != "$CI_COMMIT_BRANCH"; then
  branch=$CI_COMMIT_BRANCH
else
  # This is not a release branch
  # Extract just the qaX string from the banch name
  branch=$(echo "$CI_COMMIT_BRANCH" | sed 's/\(master-qa\)\([0-9]\)/qa\2/')
fi

# Display usage message function
usage(){
  echo -e "Usage:"
  echo -e "\t$_filename -h                          Display usage message"
  echo -e "\t$_filename [-v] build -c <container> -s <source>"
  echo -e "\t\tBuild Container"
  echo -e "\t\t-c\tContainer Name, e.g. api-fdt"
  echo -e "\t\t-s\tSource Directory relative to ./deploy folder, e.g. api-fdt"
  echo -e "\t$_filename [-v] tag -c <container>"
  echo -e "\t\tTag Container for release"
  echo -e "\t\t-c\tContainer Name, e.g. api-fdt"
  echo -e "\t$_filename [-v] push -c <container>"
  echo -e "\t\tPush container"
  echo -e "\t\t-c\tContainer Name, e.g. api-fdt"
}

build()
{
  # Check that the target directory and dockerfile exists
  if [ ! -d "$source" ]; then
    echo -e "${BRed}[ERROR]${Color_Off} Directory [${source}] does not exists, check the --source parameter"
    exit 1
  fi
  if [ ! -f "$source/Dockerfile" ]; then
    echo -e "${BRed}[ERROR]${Color_Off} File [${source}/Dockerfile] does not exists, check the --source parameter"
    exit 1
  fi

  docker build \
    --tag=registry.gitlab.com/gitlab-doctorly-demo/g/${container}:${branch:-DEV}-${CI_COMMIT_SHORT_SHA:-DEV} \
    --label \"build.version\"=\"${CI_COMMIT_SHORT_SHA:-DEV}\" \
    --label \"build.branch\"=\"${branch:-DEV}\" \
    --label \"build.pipeline\"=\"${CI_PIPELINE_ID:-DEV}\" \
    ${source}
}

tag()
{
  docker tag \
    registry.gitlab.com/gitlab-doctorly-demo/g/${container}:${branch:-DEV}-${CI_COMMIT_SHORT_SHA:-DEV} \
    registry.gitlab.com/gitlab-doctorly-demo/g/${container}:${branch:-DEV}
}

push()
{
  docker push registry.gitlab.com/gitlab-doctorly-demo/g/${container}:${branch:-DEV}-${CI_COMMIT_SHORT_SHA:-DEV}
  docker push registry.gitlab.com/gitlab-doctorly-demo/g/${container}:${branch:-DEV}
}

if [ ! 0 = $# ] # If options provided then 
then
    while getopts ":hv" opt; do # Go through the options
        case $opt in
            h ) # Help
                usage
                exit 0 # Exit correctly
            ;;
            v ) # Debug
                echo -e "Read verbose flag"
                verbose=true
            ;;
            ? ) # Invalid option
                echo -e "${BRed}[ERROR]${Color_Off}: Invalid option: -${OPTARG}"
                usage
                exit 1 # Exit with erro
            ;;
        esac
    done
    shift $((OPTIND-1))
    subcommand=$1; shift # Get subcommand and shift to next option
    case "$subcommand" in
        build )
            unset OPTIND # in order to make -v build -a <arg> -f <arg> work -> https://stackoverflow.com/questions/2189281/how-to-call-getopts-in-bash-multiple-times
            if [ $verbose == true ]; then echo -e "Read build subcommand"; fi
            if [ ! 0 == $# ] # if options provided
            then
                if [ $verbose == true ]; then echo -e "Remaining args are: <${@}>"; fi
                while getopts ":c:s:" opt; do
                    case $opt in
                        c ) # option -c with required argument
                            echo -e "Read option -c with argument ${OPTARG}"
                            container=$OPTARG
                        ;;
                        s ) # option -s with required argument
                            echo -e "Read option -s with argument ${OPTARG}"
                            source=${PROJECT_ROOT}/deploy/$OPTARG
                        ;;
                        : ) # catch no argument provided
                            echo -e "${BRed}[ERROR]${Color_Off}: option -${OPTARG} requires an argument"
                            usage
                            exit 1
                        ;;
                        ? ) # Invalid option
                            echo -e "${BRed}[ERROR]${Color_Off}: Invalid option: -${OPTARG}"
                            usage
                            exit 1 # Exit with erro
                        ;;
                    esac
                done
                if [ -z $container ] || [ -z $source ] # if variables aren't set
                then
                    echo -e "${BRed}[ERROR]${Color_Off}: Both -c & -s are required" # throw error
                    usage
                    exit 1
                fi
                shift $((OPTIND-1))
                build
            else
                usage
                exit 1
            fi
        ;;
        tag )
            unset OPTIND # in order to make -v tag -a <arg> -f <arg> work -> https://stackoverflow.com/questions/2189281/how-to-call-getopts-in-bash-multiple-times
            if [ $verbose == true ]; then echo -e "Read tag subcommand"; fi
            if [ ! 0 == $# ] # if options provided
            then
                if [ $verbose == true ]; then echo -e "Remaining args are: <${@}>"; fi
                while getopts ":c:" opt; do
                    case $opt in
                        c ) # option -c with required argument
                            echo -e "Read option -c with argument ${OPTARG}"
                            container=$OPTARG
                        ;;
                        : ) # catch no argument provided
                            echo -e "${BRed}[ERROR]${Color_Off}: option -${OPTARG} requires an argument"
                            usage
                            exit 1
                        ;;
                        ? ) # Invalid option
                            echo -e "${BRed}[ERROR]${Color_Off}: Invalid option: -${OPTARG}"
                            usage
                            exit 1 # Exit with erro
                        ;;
                    esac
                done
                if [ -z $container ] # if variables aren't set
                then
                    echo -e "${BRed}[ERROR]${Color_Off}: -c is required" # throw error
                    usage
                    exit 1
                fi
                shift $((OPTIND-1))
                tag
            else
                usage
                exit 1
            fi
        ;;
        push )
            unset OPTIND # in order to make -v push -a <arg> -f <arg> work -> https://stackoverflow.com/questions/2189281/how-to-call-getopts-in-bash-multiple-times
            if [ $verbose == true ]; then echo -e "Read push subcommand"; fi
            if [ ! 0 == $# ] # if options provided
            then
                if [ $verbose == true ]; then echo -e "Remaining args are: <${@}>"; fi
                while getopts ":c:" opt; do
                    case $opt in
                        c ) # option -c with required argument
                            echo -e "Read option -c with argument ${OPTARG}"
                            container=$OPTARG
                        ;;
                        : ) # catch no argument provided
                            echo -e "${BRed}[ERROR]${Color_Off}: option -${OPTARG} requires an argument"
                            usage
                            exit 1
                        ;;
                        ? ) # Invalid option
                            echo -e "${BRed}[ERROR]${Color_Off}: Invalid option: -${OPTARG}"
                            usage
                            exit 1 # Exit with erro
                        ;;
                    esac
                done
                if [ -z $container ] # if variables aren't set
                then
                    echo -e "${BRed}[ERROR]${Color_Off}: -c is required" # throw error
                    usage
                    exit 1
                fi
                shift $((OPTIND-1))
                push
            else
                usage
                exit 1
            fi
        ;;
        * ) # Invalid subcommand
            if [ ! -z $subcommand ]; then  # Don't show if no subcommand provided
                echo -e "Invalid subcommand: $subcommand"
            fi
            usage
            exit 1 # Exit with error
        ;;
    esac
else # else if no options provided throw error
    usage
    exit 1
fi
