#!/bin/bash
tar -c README swip.pl lib.pl misc>swip.tar
gzip -9 swip.tar
rm /var/www/dev/devel/_swip/swip.tar.gz
ln -s ~/home/sh/swip/swip.tar.gz /var/www/dev/devel/_swip/

alias swip=~/sh/swip/swip.pl
#mkdir ~/swip/;cd ~/swip/&&wget http://disarmer.ru/dev/devel/_swip/swip.tar.gz&&tar -xf swip.tar.gz&&alias swip=~/swip/swip.pl&& echo OK!