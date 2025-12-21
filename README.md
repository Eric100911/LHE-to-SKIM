# LHE-to-SKIM

## Brief Description

Fill chain MC from LHE files to MiniAOD files ready for analysis.

This chain is designed to operate on HTCondor, and is intended to be run on a large number of jobs in parallel.

**NEW:** Extended DPS (Double Parton Scattering) workflow for producing (J/psi+J/psi)+phi(1020) events with standalone Pythia8 reshowering and second hard scattering.

## How to Use

### Standard Workflow (without DPS)

For the standard workflow, submit using the `Makefile`:

1. Prepare the `LHE_sources.txt` file with the paths to the LHE files and their corresponding output MiniAOD file names.
2. Conduct a `make dryrun` to check the jobs that will be submitted.
3. If everything looks good, run `make submit` to submit the jobs to HTCondor.

### DPS Workflow (with Double Parton Scattering)

For producing DPS (J/psi+J/psi)+phi(1020) events:

1. Prepare the `LHE_sources.txt` file with extended format (see below).
2. Submit jobs using the DPS-specific submit file: `condor_submit LHE-to-SKIM-dps.sub`

#### LHE_sources.txt Format for DPS Workflow

The file can have 2 or 3 columns:

```
/path/to/LHE_file.lhe /path/to/output/MiniAOD_file.root
/path/to/LHE_file.lhe /path/to/output/MiniAOD_file.root --keep-hepmc
/path/to/LHE_file.lhe /path/to/output/MiniAOD_file.root --keep-hepmc --hepmc-dir /path/to/hepmc
```

Optional arguments in the third column:
- `--keep-hepmc`: Save the intermediate HepMC file (compressed with gzip)
- `--hepmc-dir <dir>`: Specify directory for HepMC output (default: same as MiniAOD)
- `--no-dps`: Disable DPS workflow and use standard LHE hadronization

**Note:** HepMC files are automatically compressed with gzip to save ~70-80% storage space.

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

## DPS Workflow Details

### Overview

The DPS (Double Parton Scattering) workflow extends the standard LHE-to-SKIM chain to produce (J/psi+J/psi)+phi(1020) events by:

1. **LHE Splitting**: Splits input LHE files into 30-event chunks to avoid Pythia8 core dumps
2. **Pythia8 Reshowering**: Runs standalone Pythia8 with second hard scattering in cmssw-el7 container
3. **HepMC Merging**: Merges showered chunks into a single HepMC file
4. **Standard CMSSW**: Continues with GEN-SIM → DIGI → RECO → MINIAOD workflow

### Implementation Based on Reference Repositories

This implementation follows procedures from:
- **@Eric100911/HELAC-on-HTCondor**: Standalone Pythia8 execution in cmssw-el7 container
- **@Eric100911/LHE-two-tier-split**: LHE file splitting into manageable chunks

### Key Components

#### 1. Event Splitter (`event_splitter.cpp`)

Splits LHE files into chunks of 30 events each to prevent Pythia8 crashes:

```bash
./event_splitter --input input.lhe --output-dir chunks/ --num-files N --sequential
```

Adapted from @Eric100911/LHE-two-tier-split repository.

#### 2. Pythia8 Configuration (`pythia8_lhe_to_hepmc.cmnd`)

Configures Pythia8 for:
- Reading LHE input
- Enabling multi-parton interactions (MPI)
- Second hard scattering with phi(1020) production
- J/psi → μ+μ- decay channels
- CP5 tune for Run 3

Key settings:
```
SecondHard:generate = on        # Enable second hard scattering
PhaseSpace:pTHatMinSecond = 2.0 # Min pT for phi production
333:oneChannel = 1 1.0 100 321 -321  # phi → K+K-
```

#### 3. Standalone Pythia8 Executable (`pythia8_lhe_to_hepmc.cc`)

C++ program that:
- Reads LHE input
- Performs showering with DPS
- Outputs HepMC format
- Runs in cmssw-el7 container with CMSSW environment

Build with:
```bash
cmssw-el7 --command-to-run "bash build_pythia8.sh"
```

#### 4. HepMC Merger (`merge_hepmc.sh`)

Merges multiple HepMC files from parallel reshowering:
- Handles compressed (.gz) and uncompressed files
- Preserves event headers
- Combines event records from all chunks

#### 5. Enhanced Wrapper Script (`wrapper_dps.sh`)

Orchestrates the entire DPS workflow:
1. Splits input LHE into chunks
2. Reshowers each chunk with Pythia8 (with error handling)
3. Merges successful chunks into single HepMC
4. Runs standard CMSSW workflow with HepMC input
5. Optionally saves compressed HepMC files

### HepMC File Compression

**Storage Optimization:**
- HepMC files are automatically compressed with gzip
- Compression ratio: ~70-80% reduction in file size
- Format: `.hepmc.gz`

**I/O and Processing Implications:**
- **Decompression required**: Must decompress before reading
- **I/O overhead**: Additional CPU time for decompression (~10-20% overhead)
- **Storage benefit**: Significant reduction in storage requirements
- **Transfer benefit**: Faster network transfers due to smaller size

**Usage:**
```bash
# Decompress for reading
gunzip file.hepmc.gz

# Or read directly with zcat
zcat file.hepmc.gz | your_reader
```

### Error Handling

The DPS workflow includes robust error handling:
- **Timeout protection**: 300-second timeout per chunk prevents hangs
- **Chunk-level isolation**: Failed chunks don't stop the entire job
- **Partial success**: Job continues with successfully processed chunks
- **Error logging**: Per-chunk logs for debugging

### Resource Requirements

DPS workflow requires more resources than standard workflow:
- **CPUs**: 4 (vs 2 for standard)
- **Memory**: 16 GB (vs 12 GB for standard)
- **Disk**: 8 GB (vs 4 GB for standard)
- **Time**: ~2-3x longer due to splitting, reshowering, and merging

### Configuration Files

#### For Standard Workflow:
- `wrapper.sh`: Original wrapper script
- `HadronizerGENSIM_13p6TeV_TuneCP5_pythia8_Run3Summer22.py`: LHE hadronization
- `LHE-to-SKIM.sub`: HTCondor submit file

#### For DPS Workflow:
- `wrapper_dps.sh`: Enhanced wrapper with DPS support
- `pythia8_lhe_to_hepmc.cc`: Standalone Pythia8 executable
- `pythia8_lhe_to_hepmc.cmnd`: Pythia8 configuration
- `event_splitter.cpp`: LHE splitting utility
- `merge_hepmc.sh`: HepMC merging script
- `HepMC_GENSIM_13p6TeV_Run3Summer22.py`: HepMC input for CMSSW
- `LHE-to-SKIM-dps.sub`: HTCondor submit file for DPS

### Workflow Comparison

| Feature | Standard Workflow | DPS Workflow |
|---------|------------------|--------------|
| Input | LHE file | LHE file |
| Hadronization | CMSSW Pythia8 | Standalone Pythia8 in cmssw-el7 |
| Second Hard Scattering | No | Yes (phi production) |
| LHE Splitting | No | Yes (30-event chunks) |
| Intermediate Format | None | HepMC (compressed) |
| Error Resilience | File-level | Chunk-level |
| Resource Usage | Lower | Higher |
| Output | MiniAOD | MiniAOD + optional HepMC |


