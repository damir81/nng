#!/bin/sh
#
# Copyright 2016 Garrett D'Amore <garrett@damore.org>
#
# This software is supplied under the terms of the MIT License, a
# copy of which should be located in the distribution where this
# file was obtained (LICENSE.txt).  A copy of the license may also be
# found online at https://opensource.org/licenses/MIT.
#

#
# This script is used to run uncrustify and report files that don't match.
# It looks for .c and .h files, located in ../src, and uses the config file
# uncrustify.cfg located in the same directory as this script. It only handles
# C language at this point.
#
mydir=`dirname $0`
srcdir=${mydir}/../src
failed=

vers=$(clang-format -version)
if [ $? -ne 0 ]; then
	echo "clang format not found?  Skipping checks."
	exit 0
fi

versno=${vers#clang-format version }
prefix=${vers%${versno}}

if [ "$prefix" != "clang-format version " ]
then
	echo "clang-format version misparsed.  Skipping checks."
	exit 0
fi

# strip off any -ubuntu suffix
versno=${versno%%-*}
maj=${versno%%.*}
rem=${versno#*.}
min=${rem%%.*}
	
if [ "${maj}" -lt 3 ]; then
	echo "clang-format is too old.  Skipping checks."
	exit 0
fi
if [ "${maj}" -eq 3 -a "${min}" -lt 5 ]; then
	echo "clang-format is too old.  Skipping checks."
	exit 0
fi


mytmpdir=`mktemp -d`

diffprog=${DIFF:-diff}
if [ -t 1 ]; then
	if colordiff -q /dev/null /dev/null; then
		diffprog=${DIFF:-colordiff}
	fi
fi

cd ${srcdir}
for file in `find . -name '*.[ch]' -print`
do
	ext=${file##*.}
	oldf=${file}
	newf=${mytmpdir}/new.${ext}
	# If we do not understand the format file, then do nothing
	# Our style requires a relatively modern clang-format, which is
	# older than is found on some Linux distros.
	clang-format -fallback-style=none -style=file ${oldf} > ${newf}
	cmp -s ${oldf} ${newf}
	if [ $? -ne 0 ]
	then
		echo "${file} style changes"
		${diffprog} -u $oldf $newf
		failed=1
	fi
done
rm -rf $mytmpdir
if [ -n "$failed" ]
then
	echo "Format differences found!" 1>&2
	# Sadly, there are different versions of Uncrustify, and they don't
	# seem to universally agree.  So let's not trigger a build error on
	# this -- but instead just emit it to standard output.
	exit 0
fi
