#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: oracle_runscripts
short_description: This module allows you to run free style Oracle scripts via Ansible
description:
    - Runs free-style Oracle scripts via Ansible.
version_added: "1.0"
options:
    hostName:
        description:
            - The Oracle database node
        required: false
        default: localhost
    sqlUser:
        description:
            - The Oracle user name to connect to
        required: true
    sqlPwd:
        description:
            - The Oracle user password
        required: true
    port:
        description:
            - The TNS port to connect to
        required: false
        default: 1521
    tns:
        description:
            - The TNS target to use
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
    - Requires the installation of cx_Oracle
requirements: [ "cx_Oracle" ]
author: Tim Payne
'''

EXAMPLES = '''
# Run script /tmp/i.sql on Oracleserver as user scott.
- oracle_runscripts.py hostName=oracleserver.com sqlUser=scott sqlPwd=tiger tns=orcl sqlFile=/tmp/i.sql
'''

import ConfigParser
import os
import warnings
import cx_Oracle
import string 
import sys
import getopt

def main():

    inputfile = '' 
    
    mess = ''
    module = AnsibleModule(
            argument_spec = dict(
            hostName=dict(default="localhost"),
            sqlUser=dict(required=True),
            sqlPwd=dict(required=True),
            port=dict(default=1521),
            tns=dict(required=True),
            sqlFile=dict(required=True),
            logFile=dict(default=None),
        )
    )

    hostName = module.params["hostName"]
    sqlUser = module.params["sqlUser"]
    sqlPwd = module.params["sqlPwd"]
    port = module.params["port"]
    tns = module.params["tns"]
    inputfile = module.params["sqlFile"]
    outputfile = module.params["logFile"]

    dsn = cx_Oracle.makedsn (hostName, port, tns)

    try:      
        # Connect to Oracle...
        con = cx_Oracle.connect (sqlUser, sqlPwd, dsn)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        mess = error.message
        module.fail_json(msg=mess, changed=False)
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
                
                try:
                    cur.execute(sqlQuery)
                except cx_Oracle.DatabaseError as e:
                    error, = e.args
                    mess = "Line: "+str(lineNo)+": "+sqlQuery + "->" + error.message
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
    except cx_Oracle.DatabaseError:
        pass

    if not outputfile:
        mess = "SQL file processed"

    module.exit_json(msg=mess, changed=True)

from ansible.module_utils.basic import *
main()
