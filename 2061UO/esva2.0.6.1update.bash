#!/bin/bash
#
# UNOFFICIAL update for ESVA to "2.0.6.1 UO" UNOFFICIAL
# Use at your own RISK
# For ESVA help see: http://www.esvacommunity.com/
 

#############################################
# Some Settings				    #
#############################################
DLLOC="http://www.troublenow.org/esva/2061UO"

#############################################
# Starting				    #
#############################################
echo " Did you make a snapshot of your system?  "
echo " You will now have 20 Seconds to abort (CTRL C) "
sleep 20

echo " Staring ESVA 2.0.6.1 UO update "
touch /var/esva/2061UO.started

#############################################
# 2059 updates				    #
#############################################
echo " Starting 2.0.5.9 updates "

echo " - Updating versions of esva-xxx scripts for better handling of no commandline arguments...  "
sleep 1
	cd /usr/local/sbin
    echo " -- Backing up scripts... "
    tar cvzf pre2061UO.tgz *
    rm -f esva-domainshow
    rm -f esva-mwusershow
    /usr/bin/wget $DLLOC/esva-domainshow
    /usr/bin/wget $DLLOC/esva-mwusershow
    chmod 744 *

echo " - Updating KAM.cf.sh for silent operation and better recovery... "
sleep 1
    cd /etc/cron.daily
    rm -f KAM.cf.sh
    /usr/bin/wget $DLLOC/KAM.cf.sh
    chmod 744 KAM.cf.sh

echo " - Updating Postfix's configuration... "
sleep 1
    cd /etc/postfix
    cp main.cf main.cf.pre2061UO
    postmap /etc/postfix/virtual
    postconf -e "smtpd_client_restrictions = permit_sasl_authenticated, reject_rbl_client zen.spamhaus.org"
    service postfix reload
	
echo " - Tuning httpd to run a bit leaner... "
sleep 1
    service httpd stop
    cd /etc/httpd/conf/
    mv httpd.conf httpd.conf.pre2061UO
    /usr/bin/wget $DLLOC/httpd.conf
    chmod 644 httpd.conf
    service httpd start
	
echo " - Configuring MySql to only listen to localhost... "
sleep 1
    if [ `grep bind-address /etc/my.cnf` ]; then
        echo " -- MySQL is already bound to localhost - skipping... "
    else
        cp /etc/my.cnf /etc/my.cnf.pre2061UO
        sed -i '/\[mysqld\]/ a bind-address=127.0.0.1' /etc/my.cnf
        service mysqld restart
    fi

echo " - Forcing Webmin to only listen to localhost... "
sleep 1
    if [ `grep allow= /etc/webmin/miniserv.conf` ]; then
        echo " Webmin is already bound to localhost - skipping... "
    else
        echo "allow=127.0.0.1">>/etc/webmin/miniserv.conf
        service webmin restart
    fi
	
echo " - Configuring weekly SQLGrey updates... "
sleep 1
    ln /usr/sbin/update_sqlgrey_config /etc/cron.weekly/update_sqlgrey_config
    /etc/cron.weekly/update_sqlgrey_config

echo " - Adjusting SA scores for a few rules... "
sleep 1
    sed -i '/^score FUZZY_OCR_KNOWN_HASH/d' /etc/MailScanner/spam.assassin.prefs.conf
    echo "score FUZZY_OCR_KNOWN_HASH 0.1">>/etc/MailScanner/spam.assassin.prefs.conf
    sed -i '/^score RCVD_IN_DNSWL_LOW/d' /etc/MailScanner/spam.assassin.prefs.conf
    echo "score RCVD_IN_DNSWL_LOW 0.0">>/etc/MailScanner/spam.assassin.prefs.conf

echo " Done with the 2.0.5.9 updates "
sleep 2

#############################################
# Upgrade the system to latest version	    #
#############################################
echo " Upgrading the system part 1"
sleep 2

 #Clean up YUM to avoid unsubscriptable errors
 yum clean all

 echo " - Backing up yum configs "
 sleep 1
 mv /etc/yum.conf /etc/yum.conf.pre2061UO
 
 echo " - Setting new yum configs "
 cd /etc/
 /usr/bin/wget $DLLOC/yum.conf
 mv /etc/yum.repos.d/rpmforge.repo /etc/yum.repos.d/rpmforge.repo.pre2061UO
 cd /etc/yum.repos.d
 /usr/bin/wget $DLLOC/rpmforge.repo
 
 #Configure YUM Priorities
 yum install yum-priorities -y
 echo 'priority=1'>>/etc/yum.repos.d/CentOS-Base.repo
 echo 'priority=1'>>/etc/yum.repos.d/CentOS-Media.repo
 if [ -f /etc/yum.repos.d/XenSource.repo ]; then
      echo 'priority=5'>>/etc/yum.repos.d/XenSource.repo
 fi
 echo 'priority=10'>>/etc/yum.repos.d/rpmforge.repo

 # Temporary globally disable perl updates until mailscanner install is complete
 echo 'exclude=perl'>>/etc/yum.conf

 #Stop MailScanner before we go any further
 service MailScanner stop
 
 #Remove some problematc packages and update the system
 #Removed packages will be re-installed by the MailScanner update.
echo " - Remove some packages "
 sleep 1
 rpm -e --nodeps perl-Math-BigRat
 rpm -e --nodeps perl-bignum
 rpm -e --nodeps perl-File-Temp
 rpm -e --nodeps perl-Math-BigInt

 #Update installed packages
 echo " Start system upgrade "
 sleep 2
 yum update yum -y
 yum update --skip-broken -y
 
 #Silence errors logged during WebMin startup
 yum install pam-devel perl-Authen-PAM -y
 echo '#%PAM-1.0'>/etc/pam.d/webmin
 echo 'auth  required pam_nologin.so'>>/etc/pam.d/webmin
 echo 'auth  include   system-auth'>>/etc/pam.d/webmin
 echo 'accountinclude  system-auth'>>/etc/pam.d/webmin
 echo 'password   include  system-auth'>>/etc/pam.d/webmin
 echo 'sessioninclude  system-auth'>>/etc/pam.d/webmin
 echo " Done system upgrade part 1 "
 
#############################################
# Upgrade Mailscanner 			    #
#############################################
echo " Upgrading mailscanner to 4.84.3-1 "
sleep 1
  service MailScanner stop
  cd /tmp
  wget http://www.mailscanner.info/files/4/rpm/MailScanner-4.84.3-1.rpm.tar.gz
  tar -xvzf MailScanner-*.rpm.tar.gz
  cd MailScanner*
  ./install.sh
  service sendmail stop
  chkconfig sendmail off
  chkconfig MailScanner on
  cd /etc/MailScanner
  upgrade_MailScanner_conf MailScanner.conf MailScanner.conf.rpmnew > MailScanner.new
  mv -f MailScanner.conf MailScanner.old
  mv -f MailScanner.new  MailScanner.conf
  cd /tmp
  rm -rf MailScanner*

  #Fix known problems caused by the MailScanner upgrade process
  sed -i '/^Incoming Queue Dir/ c\Incoming Queue Dir = \/var\/spool\/postfix\/hold' /etc/MailScanner/MailScanner.conf
  echo " Done Upgrading mailscanner to 4.84.3-1 "
sleep 2

#############################################
# Upgrade SpamAssassin to latest	    #
############################################# 
 echo " Upgrading SpamAssasin to Latest "
    cd /tmp
    wget http://www.mailscanner.info/files/4/install-Clam-SA-latest.tar.gz
    tar -xvzf install-Clam-SA-latest.tar.gz
    cd install-Clam*
    echo 'n'>answers.txt
    echo ''>>answers.txt
    cat answers.txt|./install.sh
    cd /tmp
    rm -rf install-Clam*
	
	# remove old files 
	rm /var/clamav/daily.cld
	rm /var/clamav/main.cld
	
    #Force an update of ClamAV definitions...
    service clamd restart
    freshclam
	
	# fix socket file in mailscanner.conf
	sed -i '/^Clamd Socket/ c\Clamd Socket = \/var\/run\/clamav\/clamd.sock' /etc/MailScanner/MailScanner.conf
	
	echo " - Restarting MailScanner after all these changes..."
    service MailScanner restart

echo " Done upgrading SpamAssasin to Latest "

#############################################
# Upgrade system part 2			    #
#############################################
echo " Upgrading the system part 1"
sleep 2

sed -i "/exclude=perl*/d" /etc/yum.conf
echo 'exclude=perl-IO perl-Scalar-List-Utils perl-bignum perl-Test-Harness perl-Test-Simple perl-Sys-Syslog perl-File-Temp perl-Math-BigRat'>>/etc/yum.repos.d/rpmforge.repo

yum update -y

echo " Done Upgrading mailscanner to 4.84.3-1 "
sleep 2

#############################################
# Removing ping home 			    #
#############################################
echo " Removing ping home "
sleep 2

rm /etc/cron.monthly/GD-Check

#############################################
# Write new issue file			    #
#############################################
echo " Writing new issue file. "
sleep 1
mv /etc/issue /etc/issue.pre2061UO
echo " *********************************************** " > /etc/issue
echo " * Email Security Virtual Appliance (ESVA)     * " >> /etc/issue
echo " * v 2.0.6.1 (Lazarus) - UNOFFICIAL            * " >> /etc/issue
echo " *                                             * " >> /etc/issue
echo " * http://www.esvacommunity.com/               * " >> /etc/issue
echo " *                                             * " >> /etc/issue
echo " *********************************************** " >> /etc/issue
echo " " >> /etc/issue
echo " Kernel \r on an \m " >> /etc/issue
echo " " >> /etc/issue
echo " " >> /etc/issue
echo "................................................. " >> /etc/issue

#############################################
# Write new Version file		    #
#############################################
echo " Writing new version file. "
sleep 2
mv /var/esva/2061UO.started /var/esva/2061UO
echo "# 2.0.6.1UO   #">/var/esva/currentversion
echo "Completed the 2.0.6.1UO update at " `date`
sleep 2
init 6 

#EOF
