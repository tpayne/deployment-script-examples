#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: postgresql_facts
short_description: This module allows you to run get key Postgres information from the database and put it into facts
description:
    - Gets Postgres information and puts it into the Ansible facts.
version_added: "1.0"
options:
    pgserver:
        description:
            - The Postgres database server
        required: false
        default: localhost
    pgport:
        description:
            - The Postgres port to connect to
        required: false
        default: 5432
    pguser:
        description:
            - The Postgres user to connect to
        required: true
    pguserpwd:
        description:
            - The password of the user
        required: true
    pgdb:
        description:
            - The Postgres database to connect to
        required: true
notes:
    - Requires the installation of psycopg2
requirements: [ "psycopg2" ]
author: Tim Payne
'''

EXAMPLES = '''
# Get the facts
postgresql_facts.py XXX
'''

import ConfigParser
import os
import warnings
import string 
import sys
import getopt
import json
import psycopg2

try:
    import psycopg2
except ImportError:
    psycopg2_installed = False
else:
    psycopg2_installed = True

# Read the Database parameters...
def read_params(cur, mess,dbParams):
    sqlQ = 'SELECT name, setting from pg_catalog.pg_settings' 

    try:
        cur.execute(sqlQ)
    except psycopg2.Error as e:
        mess[0] = sqlQ + "->" + e.pgerror
        return False

    for name, value in cur.fetchall():
        dbParams.append(dict(name=name,value=value))
 
    return True

# Read the Database parameters...
def read_dbnames(cur, mess,dbNames):
    sqlQ = 'SELECT datname, datcollate, datctype from pg_catalog.pg_database' 

    try:
        cur.execute(sqlQ)
    except psycopg2.Error as e:
        mess[0] = sqlQ + "->" + e.pgerror
        return False

    for name, collate, ctype in cur.fetchall():
        dbNames.append(dict(name=name,collate=collate,ctype=ctype))
 
    return True

# Read the Database tablespaces...
def read_tablespaces(cur, mess,dbTableSpaces):
    sqlQ = 'SELECT spcname from pg_catalog.pg_tablespace' 

    try:
        cur.execute(sqlQ)
    except psycopg2.Error as e:
        mess[0] = sqlQ + "->" + e.pgerror
        return False
    
    for tablespace_name in cur.fetchall():
        dbTableSpaces.append(dict(tablespace_name=tablespace_name))
 
    return True

# Read the Database schemas...
def read_schemas(cur,mess,dbSchemas):
    sqlQ = 'select distinct schema_name from information_schema.schemata'

    try:
        cur.execute(sqlQ)
    except psycopg2.Error as e:
        mess[0] = sqlQ + "->" + e.pgerror
        return False

    for username in cur.fetchall():
        dbSchemas.append(dict(username=username))
 
    return True

    
def main():

    mess = ['']

    module = AnsibleModule(
            argument_spec = dict(
            pgserver=dict(default="localhost"),
            pgport=dict(default=5432),
            pguser=dict(required=True),
            pguserpwd=dict(required=True),
            pgdb=dict(required=True),
        )
    )

    if not psycopg2_installed:
        module.fail_json(msg="Psycopg2 has not been located", changed=False)    
        raise

    pgserver = module.params["pgserver"]
    pgport = module.params["pgport"]
    pguser = module.params["pguser"]
    pguserpwd = module.params["pguserpwd"]
    pgdb = module.params["pgdb"]
   
    conStr = "host='"+pgserver+"'"
    conStr += " dbname='"+pgdb+"'"
    conStr += " user='"+pguser+"'"
    conStr += " password='"+pguserpwd+"'"
    conStr += " port='"+pgport+"'"
 
    try:      
        # Connect to Oracle...
        con = psycopg2.connect (conStr)
    except psycopg2.Error as e:
        mess[0] = e.pgerror
        module.fail_json(msg=mess[0], changed=False)
        raise

    cur = con.cursor()
    dbParams = list()
    if not read_params(cur,mess,dbParams):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbTableSpaces = list()
    if not read_tablespaces(cur,mess,dbTableSpaces):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbSchemas = list()
    if not read_schemas(cur,mess,dbSchemas):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbNames = list()
    if not read_dbnames(cur, mess,dbNames):
        module.fail_json(msg=mess[0], changed=False)
        raise

    module.exit_json(
        ansible_facts = dict(
          dbParams = dbParams,
          dbTableSpaces = dbTableSpaces,
          dbSchemas = dbSchemas,
          dbNames = dbNames
        ),
        changed = False
    )

from ansible.module_utils.basic import *
main()
