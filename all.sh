#!/bin/bash
set -euo pipefail
./fmSSFPsubsp.sh -g0 brain-singleslice-turnbased.cfl reco-turnbased
./fmSSFPsubsp.sh -g1 brain-singleslice-goldenangle.cfl reco-goldenangle
