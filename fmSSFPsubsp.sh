#!/bin/bash
# 2019 Volkert Roeloffs <vroeloffs@berkeley.edu>
#
# Subspace-constrained reconstruction of fmSSFP data
#
set -e

# default settings
export PATH=$TOOLBOX_PATH:$PATH
export VCOILS=10
export REG=0.0005
export LLRBLK=8
export ITER=100
export FOV=0.5
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

export READ=$(bart show -d1 $meas)
export SPOKES=$(bart show -d2 $meas) 
export COILS=$(bart show -d3 $meas)

# perform channel compression
bart cc -p$VCOILS -A -S $meas meas_cc

# create trajectory 
if [ $GA -gt 0 ] ; then
    echo "Golden Angle trajectory" >&2
    bart traj -r -G -c -x$READ -y$SPOKES traj 
else
    echo "Turn-based trajectory" >&2
    bart traj -r -c -D -x$READ -y$(($SPOKES / $P)) traj_st
    bart repmat 3 $P traj_st traj_f
    bart reshape $(bitmask 2 3) $SPOKES 1 traj_f traj
fi

# apply inverse nufft to full data set
bart nufft -i -d$READ:$READ:1 traj meas_cc img

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

# generate temporal pattern and apply to raw data 
bart delta 16 $(bart bitmask 2 5) $SPOKES pattern 
bart fmac meas_cc pattern meas_t
bart repmat 1 $READ pattern pattern_full

# reconstruction with subspace constraint
bart pics -SeH -d5 -R L:3:3:$REG -i$ITER -f$FOV \
    -t traj -B basis -p pattern_full meas_t sens reco

#crop to actual FoV and combine coefficients with RSS
size=$(bc -l <<< "0.5 * $READ")
bart resize -c 0 $size 1 $size reco reco_cropped 
bart rss $(bart bitmask 6) reco_cropped $output

#write out reconstruction as png
bart toimg -W $output $output

} > $LOGFILE

exit 0
