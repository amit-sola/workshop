#!/bin/bash
# A simple demonstration of variables
# 
 
name=Amit
echo "           "
echo    Hello everyone, This is  $name
echo "           "

# you can use environment users as well
#
echo username :  $USER
echo "           "

operations=`cat $1 | wc -l`
echo The number of lines / operations in the file $1 is $operations
echo "           "
echo "           "
