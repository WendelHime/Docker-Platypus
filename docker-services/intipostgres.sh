#!/bin/bash
#export PATH=$PATH:/usr/lib/postgresql/9.6/bin/
#su postgres -c "pg_ctl start"
/etc/init.d/postgresql start
sleep 2
su postgres -c "createuser -d -l -r -w -e chadouser"
su postgres -c "psql template1 -c 'CREATE DATABASE curtobacterium_db' -Uchadouser"
su postgres -c "psql curtobacterium_db < curtobacterium_db.sql"
/etc/init.d/apache2 restart
/etc/init.d/postgresql restart
apachectl -DFOREGROUND
tail -f /var/log/apache2/error.log

