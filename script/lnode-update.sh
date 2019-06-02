#!/bin/sh

rm -rf /tmp/usr/
rm -rf /tmp/package.json
unzip -q /usr/local/lnode/update/update.zip -d /tmp/
chmod 777 /tmp/usr/local/lnode/bin/lnode
ln -s /usr/local/lnode/update/ /tmp/usr/local/lnode/update
echo 'install...'
/tmp/usr/local/lnode/bin/lnode /tmp/usr/local/lnode/app/lpm/bin/lpm install
