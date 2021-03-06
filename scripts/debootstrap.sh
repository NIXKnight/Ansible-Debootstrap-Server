#!/usr/bin/env bash

set -exo pipefail

ANSIBLE_OVERRIDES=
CHROOT_PATH=

# Function to set ANSIBLE_OVERRIDES
function setAnsibleOverrides {
  if [ -f $1 ] ; then
    if [[ -z $ANSIBLE_OVERRIDES ]] ; then
      ANSIBLE_OVERRIDES=" -e @$1"
    else
      ANSIBLE_OVERRIDES="$ANSIBLE_OVERRIDES -e @$1"
    fi
  else
    echo -e "Override file $1 is not found!\nExiting..."
    exit 1
  fi
}

# Parameters to be used by the script
SHORT_OPTS="o:,c:"
OPTS=$(getopt --shell bash --options $SHORT_OPTS -- $@)

# Quit with error status if no or invalid parameter is provided
NUMARGS="$#"
if [ $? != 0 ] ; then
  echo -e "Error! NUMARGS is non zero..."
  exit 1
elif [[ $NUMARGS -eq 0 ]] ; then
  echo -e "Error! NUMARGS is 0..."
  exit 1
fi

eval set -- "$OPTS"

# Parse parameters
while true ; do
  case "$1" in
    -o)
      setAnsibleOverrides $2
      shift 2
      ;;
    -c)
      CHROOT_PATH=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo -e "Error! No or invalid parameter(s)..."
      exit 1
      ;;
  esac
done

# Setup Python virtual environment
if [[ -d /tmp/ansible_venv ]] ; then
  echo -e "Ansible virtualenv already exists.\nSkipping virtual environment setup..."
else
  echo -e "Setting up Python virtual environment..."
  if ! command -v virtualenv &> /dev/null ; then
    echo -e "virtualenv not found!"
    echo -e "Installing virtualenv via apt..."
    apt update && apt -y install virtualenv
  fi
  virtualenv --python=/usr/bin/python3 /tmp/ansible_venv
fi

# Install Ansible
apt-get install jq
echo -e "Installing Ansible..."
source /tmp/ansible_venv/bin/activate
pip install -r requirements/requirements.txt
pip install yq

# Install additional Ansible roles
ansible-galaxy install --roles-path playbooks/external-roles -r requirements/requirements.yml --force

# Run Ansible playbooks
cd playbooks
ansible-playbook  -e ansible_python_interpreter="/usr/bin/python3" $ANSIBLE_OVERRIDES debootstrap.yml -vv
ansible-playbook -i "$CHROOT_PATH," -e ansible_python_interpreter="/usr/bin/python3" $ANSIBLE_OVERRIDES chroot_run.yml -vv
