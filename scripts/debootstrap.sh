#!/usr/bin/env bash

set -exuo pipefail

ANSIBLE_OVERRIDES=
ANSIBLE_PLAYBOOKS=

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

# Function to set ANSIBLE_PLAYBOOKS
function setAnsiblePlaybooks {
  if [ -f playbooks/$1 ] ; then
    if [[ -z $ANSIBLE_PLAYBOOKS ]] ; then
      ANSIBLE_PLAYBOOKS=" @$1"
    else
      ANSIBLE_PLAYBOOKS="$ANSIBLE_PLAYBOOKS @$1"
    fi
  else
    echo -e "Playbook file $1 is not found!\nExiting..."
    exit 1
  fi
}

# Parameters to be used by the script
SHORT_OPTS="o:,p:"
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
    -p)
      setAnsiblePlaybooks $2
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
echo -e "Setting up Python virtual environment..."
if ! command -v virtualenv &> /dev/null ; then
  echo -e "virtualenv not found!"
  echo -e "Installing virtualenv via apt..."
  apt update && apt -y install virtualenv
fi
virtualenv --python=/usr/bin/python3 /tmp/ansible_venv

# Install Ansible
echo -e "Installing Ansible..."
source /tmp/ansible_venv/bin/activate
pip install -r requirements/requirements.txt

# Install additional Ansible roles
ansible-galaxy install --roles-path playbooks/external-roles -r requirements/requirements.yml

# Run Ansible playbook(s)
cd playbooks
for playbook in "$(cat $ANSIBLE_PLAYBOOKS)" ; do
  ansible-playbook $ANSIBLE_OVERRIDES $playbook -vv
done
