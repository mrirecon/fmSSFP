
**Main repository has moved to: https://gitlab.tugraz.at/ibi/mrirecon/papers/fmssfp**

**Please check there for updates.**


# fmSSFP
bash script and demo data for subspace-constrained fmSSFP reconstruction

This fully BART-based routine performs a reconstruction in the style of

Roeloffs et al. Frequency‐modulated SSFP with radial sampling and subspace
reconstruction: A time‐efficient alternative to phase‐cycled bSSFP.
Magnetic Resonance in Medicine 81:1566-1579 (2019)
[DOI: 10.1002/mrm.27505](https://doi.org/10.1002/mrm.27505)


example usage assuming BART $TOOLBOX_PATH is set correctly:

$ ./fmSSFPsubsp.sh -g0 brain-singleslice-turnbased.cfl reco 

will perform the reconstruction and save it as "reco.cfl".

Total runtime of these scripts should be less than a minute.

Try in your browser (no setup required):

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/mrirecon/fmSSFP/master?filepath=run.ipynb)



[![BART](./bart.svg)](https://mrirecon.github.io/bart)

