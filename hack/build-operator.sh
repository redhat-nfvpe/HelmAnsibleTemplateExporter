#!/bin/sh
#
set -o pipefail
base_dir=$(cd $(dirname $0)/../ && pwd)  #base direct where binay is executed
source "$base_dir/hack/lib.sh"
source "$base_dir/hack/init.sh"
source "$base_dir/hack/install_requirements.sh"

if [ $# -eq 0 ]; then
  usage
  exit
fi


while [ -n "$1" ]; do # while loop starts
  case "$1" in
  -e | --export) export=true ;; #export helm charts
  -b | --build) build=true ;; #export helm charts
  -d | --deploy) deploy=true ;; #deploy the build operator
  -r | --run) run_operator=true ;; # to run the operator outside the cluster
  -c | --delete) delete=true ;; #export helm charts
  -h | --help)
    usage
    exit
    ;;
  *)
    echo "Option $1 not recognized"
    usage
    exit
    ;;
  esac

  shift

done

#DO NOT CHANGE BELOW THIS LINE
#exported template folder
#Check if folder exists
eval workspace="$workspace"
mkdir -p "$workspace"
workspace_base_dir=$(cd $(dirname "$workspace/../") && pwd)
template_dir="$workspace_base_dir/$role"
#Operator build
operator_dir="$workspace_base_dir/$operator"
#If you are runing this script against example zetcd
#1.Export helm charts to Ansible
#2.Remove Reference to tpl, include, template and sprig function
# These are the cases not supported (include tuple for loops)
#3.Build Ansible Operator-sdk
#4 Copy Exported Ansible in to operator generated by Operator-SDK
# Copy To  roles/${role}/defaults from roles/${role}/default
# Copy to roles/${role}/templates from roles/${role}/templates
# Copy to roles/${role}/tasks from roles/${role}/tasks

echo "Operator for :"
echo "Role: $role"
echo "Operator Name: ${operator}"
echo "Helm location : ${helm_chart}"
echo "Output location : ${workspace}"


if ! which operator-sdk 2>&1 >/dev/null; then
  install_operator_sdk
fi

if [[ ! -z "$export" && "$export" == true ]]; then
  validate
  #Export helm
  export_helm
  #Generating Operator SDK
  generate_operator
  #Copy templates from ported templates to operator
  copy_assets "$template_dir" "$operator_dir" "$role"
fi

#you need to build first
if [[ ! -z "$build" && "$build" == true ]]; then
  if [[ "$quay_namespace" == 'YOUR_NAMESPACE' ]]; then
  echo "Please update quay_namespace to a valid namespace in env.sh or set via cli."
  exit 1
  fi
  build_operator_image
fi
if [[ ! -z "$deploy" && "$deploy" == true ]]; then
  deploy_operator
elif [[ ! -z "$run_operator" && "$run_operator" == true ]]; then
  cd "$operator_dir" || exit 1
  operator-sdk up local \
    --namespace=default \
    --operator-flags="-dev"
fi
#delete if you want to clean the cluster
if [[ ! -z "$delete" && "$delete" == true ]]; then
  delete_operator
fi
