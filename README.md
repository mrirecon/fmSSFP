# fmSSFP
bash script and demo data for subspace-constrained fmSSFP reconstruction

This fully BART-based routine performs a reconstruction in the style of
(Roeloffs et al., "Frequency‐modulated SSFP with radial sampling and subspace reconstruction: A time‐efficient alternative to phase‐cycled bSSFP", https://doi.org/10.1002/mrm.27505)


example usage assuming BART $TOOLBOX_PATH is set correctly:

$ ./fmSSFPsubsp.sh -g0 brain-singleslice-turnbased.cfl reco 

will perform the reconstruction, save it as "reco.cfl" and generate an image "reco.png" 
