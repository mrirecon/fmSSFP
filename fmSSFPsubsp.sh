#!/bin/bash
# 2019 Volkert Roeloffs <vroeloffs@berkeley.edu>
#
# Subspace-constrained reconstruction of fmSSFP data
# This script is derived from the grasp.sh script of the BART toolbox.
# See the LICENSE file for copyright information.
set -e

# default settings
export PATH=$TOOLBOX_PATH:$PATH
export VCOILS=10
export REG=0.0005
export LLRBLK=8
export ITER=100
export FOV=1.
GA=1 #0: turn-based sampling, 1: Golden Angle sampling
P=4
LOGFILE=/dev/stdout
title=$(cat <<- EOF
	BART-based fmSSFP reco v0.1
EOF
)

helpstr=$(cat <<- EOF
Subspace-constrained reconstruction of fmSSFP data
Input data is assumed to be one slice of a 3D stack-of-stars data set.
The sampling pattern is assumed to follow a Golden Angle trajectory (default)
or a single-turn pattern where the number of repetitions equals the subspace size.
This script requires the Berkeley Advanced Reconstruction Toolbox
version 0.4.04. (later versions may also work).
EOF
)

usage="Usage: $0 [-h] [-l logfile] [-g GAflag] <meas.cfl> <output>"

echo "$title"
echo

while getopts "hl:g:" opt; do
        case $opt in
	h)
		echo "$usage"
		echo
		echo "$helpstr"
		exit 0
	;;
	l)
		LOGFILE=$(readlink -f "$OPTARG")
	;;
    g)
        GA=$OPTARG
    ;;      
    \?)
        echo "$usage" >&2
		exit 1
    ;;
    esac
done

shift $((OPTIND - 1))

if [ $# -lt 2 ] ; then
        echo "$usage" >&2
        exit 1
fi

input=$(readlink -f "$1")
output=$(readlink -f "$2")

if [ ! -e $input ] ; then
	echo "Input file does not exist." >&2
	echo "$usage" >&2
	exit 1
fi
meas=${input%.cfl}
if [ ! -e $TOOLBOX_PATH/bart ] ; then
        echo "\$TOOLBOX_PATH is not set correctly!" >&2
	exit 1
fi

#WORKDIR=$(mktemp -d)
# Mac: http://unix.stackexchange.com/questions/30091/fix-or-alternative-for-mktemp-in-os-x
WORKDIR=`mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir'`
trap 'rm -rf "$WORKDIR"' EXIT
cd $WORKDIR

# start group for redirection of output to the logfile
{

OREAD=$(bart show -d1 $meas)
SPOKES=$(bart show -d2 $meas)
COILS=$(bart show -d3 $meas)

# perform channel compression
bart cc -p$VCOILS -A -S $meas meas_cc

# create trajectory 
if [ $GA -gt 0 ] ; then
    echo "Golden Angle trajectory" >&2
    bart traj -r -G -c -x$OREAD -y$SPOKES traj
else
    echo "Turn-based trajectory" >&2
    bart traj -r -c -D -x$OREAD -y$(($SPOKES / $P)) traj_st
    bart repmat 3 $P traj_st traj_f
    bart reshape $(bart bitmask 2 3) $SPOKES 1 traj_f traj
fi

# remove oversampling
READ=$(($OREAD / 2))
bart scale 0.5 traj traj2


# apply inverse nufft to full data set
bart nufft -i -d$READ:$READ:1 traj2 meas_cc img

# transform back to k-space and compute sensitivities
bart fft -u $(bart bitmask 0 1 2) img ksp

# transpose because we already support off-center calibration region
# in dim 0 but here we might have it in 2
bart transpose 0 2 ksp ksp2
bart ecalib -S -t0.01 -m1 ksp2 sens2
bart transpose 0 2 sens2 sens

# generate low frequency Fourier basis
bart delta 16 $(bart bitmask 5 6) $SPOKES eye 
bart fft -i $(bart bitmask 5) eye dftmtx
bart crop 6 $P dftmtx basis

# transform data
bart transpose 2 5 meas_cc meas_t
bart transpose 2 5 traj2 traj_t

# transform data
bart transpose 2 5 meas_cc meas_t
bart transpose 2 5 traj2 traj_t

# reconstruction with subspace constraint
bart pics -SeH -d5 -R L:3:3:$REG -i$ITER -f$FOV \
    -t traj_t -B basis meas_t sens reco

#combine coefficients with RSS
bart rss $(bart bitmask 6) reco $output

} > $LOGFILE

exit 0
