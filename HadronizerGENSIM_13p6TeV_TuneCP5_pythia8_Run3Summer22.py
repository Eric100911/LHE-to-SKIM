# Auto generated configuration file
# using: 
# Revision: 1.19 
# Source: /local/reps/CMSSW/CMSSW/Configuration/Applications/python/ConfigBuilder.py,v 
# with command line options: Configuration/Generator/python/Hadronizer_TuneCP5_13TeV_MLM_5f_max4j_LHE_pythia8_cff.py --mc --no_exec --python_filename JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_GENSIM.py --eventcontent RAWSIM --step GEN,SIM --datatier GEN-SIM --conditions 124X_mcRun3_2022_realistic_v12 --beamspot Realistic25ns13p6TeVEarly2022Collision --era Run3 --geometry DB:Extended -n -1 --customise Configuration/DataProcessing/Utils.addMonitoring --nThreads 8 --nStreams 8 --filein file:JJY_TPS_test.lhe --fileout file:JJY1S_TPS_6Mu_13p6TeV_TuneCP5_pythia8_Run3Summer22_GENSIM.root
import FWCore.ParameterSet.Config as cms

from Configuration.Eras.Era_Run3_cff import Run3

process = cms.Process('SIM',Run3)

# import of standard configurations
process.load('Configuration.StandardSequences.Services_cff')
process.load('SimGeneral.HepPDTESSource.pythiapdt_cfi')
process.load('FWCore.MessageService.MessageLogger_cfi')
process.load('Configuration.EventContent.EventContent_cff')
process.load('SimGeneral.MixingModule.mixNoPU_cfi')
process.load('Configuration.StandardSequences.GeometryRecoDB_cff')
process.load('Configuration.StandardSequences.GeometrySimDB_cff')
process.load('Configuration.StandardSequences.MagneticField_cff')
process.load('Configuration.StandardSequences.Generator_cff')
process.load('IOMC.EventVertexGenerators.VtxSmearedRealistic25ns13p6TeVEarly2022Collision_cfi')
process.load('GeneratorInterface.Core.genFilterSummary_cff')
process.load('Configuration.StandardSequences.SimIdeal_cff')
process.load('Configuration.StandardSequences.EndOfProcess_cff')
process.load('Configuration.StandardSequences.FrontierConditions_GlobalTag_cff')

process.maxEvents = cms.untracked.PSet(
    input = cms.untracked.int32(-1),
    output = cms.optional.untracked.allowed(cms.int32,cms.PSet)
)

# Input source
process.source = cms.Source("LHESource",
    fileNames = cms.untracked.vstring([
        'file:input.lhe'
    ])
)

process.options = cms.untracked.PSet(
    FailPath = cms.untracked.vstring(),
    IgnoreCompletely = cms.untracked.vstring(),
    Rethrow = cms.untracked.vstring(),
    SkipEvent = cms.untracked.vstring(),
    accelerators = cms.untracked.vstring('*'),
    allowUnscheduled = cms.obsolete.untracked.bool,
    canDeleteEarly = cms.untracked.vstring(),
    deleteNonConsumedUnscheduledModules = cms.untracked.bool(True),
    dumpOptions = cms.untracked.bool(False),
    emptyRunLumiMode = cms.obsolete.untracked.string,
    eventSetup = cms.untracked.PSet(
        forceNumberOfConcurrentIOVs = cms.untracked.PSet(
            allowAnyLabel_=cms.required.untracked.uint32
        ),
        numberOfConcurrentIOVs = cms.untracked.uint32(0)
    ),
    fileMode = cms.untracked.string('FULLMERGE'),
    forceEventSetupCacheClearOnNewRun = cms.untracked.bool(False),
    makeTriggerResults = cms.obsolete.untracked.bool,
    numberOfConcurrentLuminosityBlocks = cms.untracked.uint32(0),
    numberOfConcurrentRuns = cms.untracked.uint32(1),
    numberOfStreams = cms.untracked.uint32(1),
    numberOfThreads = cms.untracked.uint32(1),
    printDependencies = cms.untracked.bool(False),
    sizeOfStackForThreadsInKB = cms.optional.untracked.uint32,
    throwIfIllegalParameter = cms.untracked.bool(True),
    wantSummary = cms.untracked.bool(False)
)

# Production Info
process.configurationMetadata = cms.untracked.PSet(
    annotation = cms.untracked.string('Configuration/Generator/python/Hadronizer_TuneCP5_13TeV_MLM_5f_max4j_LHE_pythia8_cff.py nevts:-1'),
    name = cms.untracked.string('Applications'),
    version = cms.untracked.string('$Revision: 1.19 $')
)

# Output definition

process.RAWSIMoutput = cms.OutputModule("PoolOutputModule",
    SelectEvents = cms.untracked.PSet(
        SelectEvents = cms.vstring('generation_step')
    ),
    compressionAlgorithm = cms.untracked.string('LZMA'),
    compressionLevel = cms.untracked.int32(1),
    dataset = cms.untracked.PSet(
        dataTier = cms.untracked.string('GEN-SIM'),
        filterName = cms.untracked.string('')
    ),
    eventAutoFlushCompressedSize = cms.untracked.int32(20971520),
    fileName = cms.untracked.string('file:step1_GENSIM.root'),
    outputCommands = process.RAWSIMEventContent.outputCommands,
    splitLevel = cms.untracked.int32(0)
)

# Additional output definition

# Other statements
if hasattr(process, "XMLFromDBSource"): process.XMLFromDBSource.label="Extended"
if hasattr(process, "DDDetectorESProducerFromDB"): process.DDDetectorESProducerFromDB.label="Extended"
process.genstepfilter.triggerConditions=cms.vstring("generation_step")
from Configuration.AlCa.GlobalTag import GlobalTag
process.GlobalTag = GlobalTag(process.GlobalTag, '124X_mcRun3_2022_realistic_v12', '')

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.Pythia8aMCatNLOSettings_cfi import *
from Configuration.Generator.PSweightsPythia.PythiaPSweightsSettings_cfi import *
from Configuration.Generator.MCTunesRun3ECM13p6TeV.PythiaCP5Settings_cfi import *

process.generator = cms.EDFilter("Pythia8ConcurrentHadronizerFilter",
    PythiaParameters = cms.PSet(
        pythia8CommonSettingsBlock,       # Common Pythia8 settings  
        pythia8CP5SettingsBlock,          # CMS CP5 tune for Pythia8 
        pythia8aMCatNLOSettingsBlock,     # Settings for aMC@NLO matching  
        pythia8PSweightsSettingsBlock,    # Settings for parton shower (PS) weights  

        processParameters = cms.vstring(
            "TimeShower:nPartonsInBorn = -1",     # Number of partons in Born process (-1 = auto)  
            "TimeShower:mMaxGamma = 4",           # Maximum photon energy in final-state QED shower (GeV)  
            "PDF:pSet = 7",                       # Use PDF set ID 7   
            
            # Decay mode settings
            "23:onMode = 0",                      # Disable all decays of Z boson  
            "23:onIfMatch = 13 -13",              # Allow only Z to mu+mu-
            "443:onMode = 0",                     # Disable all decays of Jpsi 
            "443:onIfMatch = 13 -13",             # Allow only Jpsi to mu+mu- decay
            "20443:onMode = 0",                   # Disable all decays of Chi_c1  
            "20443:onIfAny = 443",                # Allow Chi_c1 to Jpsi decay  
            "445:onMode = 0",                     # Disable all decays of Chi_c2  
            "445:onIfAny = 443",                  # Allow Chi_c2 to Jpsi decay  
            "10441:onMode=0",                     # Disablealldecaysofh_c
            "10441:onIfAny = 443",                # Allow h_c to Jpsi decay  
            "100443:onMode = 0",                  # Disable all decays of psi(2S)  
            "100443:onIfAny = 443",               # Allow psi(2S) to Jpsi decay 
            "553:onMode = 0",                     # Disable all decays of Upsilon(1S)
            "553:onIfMatch = 13 -13",             # Allow Upsilon(1S) to mu+mu- decay
            "100553:onMode = 0",                  # Disable all decays of Upsilon(2S)
            "100553:onIfMatch = 13 -13",          # Allow Upsilon(2S) to mu+mu- decay
            "200553:onMode = 0",                  # Disable all decays of Upsilon(3S)
            "200553:onIfMatch = 13 -13",          # Allow Upsilon(3S) to mu+mu- decay
        ),

        parameterSets = cms.vstring(
            "pythia8CommonSettings",      
            "pythia8CP5Settings",         
            "pythia8aMCatNLOSettings",    
            "processParameters",          
            "pythia8PSweightsSettings"    
        )
    ),
    comEnergy = cms.double(13600),                    # Collision energy, needs to be same as the setting in HELAC-Onia.
    maxEventsToPrint = cms.untracked.int32(0),        # Do not print event details  
    pythiaHepMCVerbosity = cms.untracked.bool(False), # Disable HepMC event output verbosity  
    pythiaPylistVerbosity = cms.untracked.int32(0),   # Disable Pythia event listing output  
    filterEfficiency = cms.untracked.double(1.0),     # Set filter efficiency to 1.0 (all events pass)  
)


process.ProductionFilterSequence = cms.Sequence(process.generator)

# Path and EndPath definitions
process.generation_step = cms.Path(process.pgen)
process.simulation_step = cms.Path(process.psim)
process.genfiltersummary_step = cms.EndPath(process.genFilterSummary)
process.endjob_step = cms.EndPath(process.endOfProcess)
process.RAWSIMoutput_step = cms.EndPath(process.RAWSIMoutput)

# Schedule definition
process.schedule = cms.Schedule(process.generation_step,process.genfiltersummary_step,process.simulation_step,process.endjob_step,process.RAWSIMoutput_step)
from PhysicsTools.PatAlgos.tools.helpers import associatePatAlgosToolsTask
associatePatAlgosToolsTask(process)

#Setup FWK for multithreaded
process.options.numberOfThreads = 4
process.options.numberOfStreams = 4
# filter all path with the production filter sequence
for path in process.paths:
	getattr(process,path).insert(0, process.ProductionFilterSequence)

# customisation of the process.

# Automatic addition of the customisation function from Configuration.DataProcessing.Utils
from Configuration.DataProcessing.Utils import addMonitoring 

#call to customisation function addMonitoring imported from Configuration.DataProcessing.Utils
process = addMonitoring(process)

# End of customisation functions


# Customisation from command line

# Add early deletion of temporary data products to reduce peak memory need
from Configuration.StandardSequences.earlyDeleteSettings_cff import customiseEarlyDelete
process = customiseEarlyDelete(process)
# End adding early deletion
