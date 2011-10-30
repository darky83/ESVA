#!/bin/bash
#
cd /tmp
wget -q http://www.troublenow.org/esva/2061UO/esva2.0.6.1update.bash
chmod 755 /tmp/esva2.0.6.1update.bash
logsave -a /tmp/esva2061UOupdater.log  /tmp/esva2.0.6.1update.bash

