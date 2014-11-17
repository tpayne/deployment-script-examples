#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: postgresql_runscripts
short_description: This module allows you to run free style Postgres scripts via Ansible
description:
    - Runs free-style Postgres scripts via Ansible.
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
    sqlFile:
        description:
            - The name of the script file to run
        required: true
    logFile:
        description:
            - Log file in which to put output
        required: false
        default: null
 
notes:
    - Requires the installation of psycopg2
requirements: [ "psycopg2" ]
author: Tim Payne
'''

EXAMPLES = '''
# Run script /tmp/i.sql on Oracleserver as user scott.
postgresql_runscripts.py pgserver={{postgres_host}} pgport=5432 pguser=postgres pguserpwd={{PostgresqlPwd}} pgdb=test sqlFile=/tmp/i.sql
'''

import ConfigParser
import os
import warnings
import string 
import sys
import getopt
import json

try:
    import psycopg2
except ImportError:
    psycopg2_installed = False
else:
    psycopg2_installed = True

def main():

    inputfile = '' 
    
    mess = ''

    module = AnsibleModule(
            argument_spec = dict(
            pgserver=dict(default="localhost"),
            pgport=dict(default=5432),
            pguser=dict(required=True),
            pguserpwd=dict(required=True),
            pgdb=dict(required=True),
            sqlFile=dict(required=True),
            logFile=dict(default=None),
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
    inputfile = module.params["sqlFile"]
    outputfile = module.params["logFile"]
   
    conStr = "host='"+pgserver+"'"
    conStr += " dbname='"+pgdb+"'"
    conStr += " user='"+pguser+"'"
    conStr += " password='"+pguserpwd+"'"
    conStr += " port='"+pgport+"'"

    try:      
        # Connect to Postgres...
        con = psycopg2.connect (conStr)
    except psycopg2.Error as e:
        mess[0] = e.pgerror
        module.fail_json(msg=mess[0], changed=False)
        raise

    # If an output file has been specified, then create one
    if (outputfile) and outputfile != 'STDOUT':
        ofs = open(outputfile, "w")
 
    sqlQuery = ''
    cur = con.cursor()
    with open(inputfile, 'r') as inp:
        lineNo = 0
        for line in inp:
            lineNo = lineNo + 1
            line = line.strip()
            line = line.lstrip()
            # Skip any blank lines or SQL remark characters
            if line == '\n' or line.find('--',0,2) != -1 or line.find('REM',0,3) != -1:
                sqlQuery = ''
            elif line == '/\n' or line.find(';') != -1:
                sqlQuery = sqlQuery + line
                sqlQuery = sqlQuery.strip()
                sqlQuery = sqlQuery.strip(';')
                sqlQuery = sqlQuery.strip('/')
                sqlQuery = sqlQuery.strip('\n')
                
                if sqlQuery and not sqlQuery.isspace():
                    try:
                        cur.execute(sqlQuery)
                    except psycopg2.DatabaseError, e: 
                        mess = "Line: "+str(lineNo)+": "+sqlQuery + "->" + e.pgerror
                        module.fail_json(msg=mess, changed=False)
                        raise

                    if (outputfile) and outputfile != 'STDOUT':
                        ofs.write(sqlQuery+"\nCommand processed\n")
                    elif (outputfile) and outputfile == 'STDOUT':
                        mess = mess + sqlQuery+"\nCommand processed\n"

                sqlQuery = ''

            else:
                sqlQuery = sqlQuery + line
    
    try:
        if (outputfile) and outputfile != 'STDOUT':
            ofs.close()
        inp.close()
        cur.close()
        con.close()
    except psycopg2.Error as e:
        pass

    if not outputfile:
        mess = "SQL file processed"

    module.exit_json(msg=mess, changed=True)

from ansible.module_utils.basic import *
main()
