#!/bin/sh -xv

echo "Run some samples..."
ansible-playbook -i ansible_hosts simple_playbook.yml
ansible-playbook -i ansible_hosts playbook_batch.yml
ansible-playbook -i ansible_hosts playbook_delegate.yml
ansible-playbook -i ansible_hosts playbook_env.yml
ansible-playbook -i ansible_hosts playbook_errorhandling.yml

ansible-playbook -i ansible_hosts playbook_factsassert.yml
ansible-playbook -i ansible_hosts playbook_lists.yml 
ansible-playbook -i ansible_hosts playbook_module.yml
ansible-playbook -i ansible_hosts playbook_rc.yml

ansible-playbook -i ansible_hosts playbook_nestedloops.yml

echo "You need to press return after the polling..."
ansible-playbook -i ansible_hosts playbook_polling.yml 

