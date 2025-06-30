# LHE-to-SKIM

## Brief Description

Fill chain MC from LHE files to MiniAOD files ready for analysis.

This chain is designed to operate on HTCondor, and is intended to be run on a large number of jobs in parallel.

## How to Use

## Implementation

### HTCondor jobs

The jobs are "event-file-driven", i.e. each job processes a single LHE file.

The files to be processed and the name of their final MiniAOD output files are specified in the `LHE_sources.txt` file. Each line in this file should contain a single LHE file path as an EOS absolute path and the corresponding MiniAOD output file name. The format is:

```
/path/to/LHE_file.lhe /path/to/output/MiniAOD_file.root
```

Given that HTCondor cannot transfer data to CERN EOS via the regular process, direct copying will be the way to go for both the input LHE and output MiniAOD files.

### `CMSSW` Config and Wrapper Script

The steps are separated into different `CMSSW` config scripts, each responsible for a specific step in the chain:

* GEN-SIM: `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_GENSIM.py`
* RAW: `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_RAW.py`
* RECO: `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_RECO.py`
* SKIM: `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_SKIM.py`

A wrapper script is used to ensure a sequential execution of these steps, handling the dependencies between them. It takes the path of the LHE file as an argument and executes the steps in the correct order:

1. Configure the environment for the `CMSSW` releases.
2. Copy the LHE file to the local scratch directory as "JJY_TPS_test.lhe".
3. `cd` into a `CMSSW_12_4_14_patch3` directory for the GEN-SIM, RAW, and RECO steps.
3. Run the GEN-SIM step using the `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_GENSIM.py` config.
4. Run the RAW step using the `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_RAW.py` config.
5. Run the RECO step using the `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_RECO.py` config.
6. `cd` into a `CMSSW_13_0_13` directory for the SKIM step. Move the output from the RECO step to this directory.
7. Run the SKIM step using the `JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_SKIM.py` config.
8. Copy the output MiniAOD file back to EOS.
9. Clean up the local scratch directory.

Notably, the SKIM step will require a different `CMSSW` release. In our case, the rest will be run in `CMSSW_12_4_14_patch3`, while the SKIM step will be run in `CMSSW_13_0_13`.

### Log files

Direct log files and `CMSSW` `FrameworkJob.xml` files are generated for each step in the chain, each with a unique name based on the LHE file being processed and the step being executed.


