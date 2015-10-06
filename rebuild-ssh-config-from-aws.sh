#!/bin/bash

if [ $# -lt 1 ]; then
	echo "Usage: rebuild-ssh-config <profile-1> <profile-2> ..." 
fi

CUR_DIR=`pwd`
EXEC_DIR=`dirname $0`
cd $EXEC_DIR;

for var in "$@"
do
	bundle exec $EXEC_DIR/ssh-servers-from-aws.rb "$var" > /dev/null 2>&1
done

cd $CUR_DIR;

### Concat all the ssh config files into the main file
### WARNING: This will erase your current .ssh/config file! Move stuff you want to keep into an .sshconfig file in the ssh folder here.

rm ~/.ssh/config
 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for i in `ls $DIR/ssh/*.sshconfig` ; do
  cat $i >> ~/.ssh/config
  echo >> ~/.ssh/config
  echo >> ~/.ssh/config
done

chmod 600 ~/.ssh/config
