// Standalone Pythia8 program for LHE to HepMC conversion with DPS
// Reads LHE file, performs showering with second hard scattering, outputs HepMC
//
// Usage: ./pythia8_lhe_to_hepmc <config_file> <input_lhe> <output_hepmc> [seed]
//
// Based on the workflow described in Eric100911/HELAC-on-HTCondor

#include "Pythia8/Pythia.h"
#include "Pythia8Plugins/HepMC3.h"
#include <iostream>
#include <string>
#include <cstdlib>

using namespace Pythia8;

int main(int argc, char* argv[]) {
    
    // Check command line arguments
    if (argc < 4 || argc > 5) {
        std::cerr << "Usage: " << argv[0] 
                  << " <config_file> <input_lhe> <output_hepmc> [seed]" << std::endl;
        std::cerr << "  config_file  : Pythia8 configuration file (.cmnd)" << std::endl;
        std::cerr << "  input_lhe    : Input LHE file" << std::endl;
        std::cerr << "  output_hepmc : Output HepMC file (will be created)" << std::endl;
        std::cerr << "  seed         : Optional random seed (default: 0 = time-based)" << std::endl;
        return 1;
    }

    std::string configFile = argv[1];
    std::string inputLHE = argv[2];
    std::string outputHepMC = argv[3];
    int randomSeed = (argc == 5) ? std::atoi(argv[4]) : 0;

    std::cout << "==================================================================" << std::endl;
    std::cout << "Pythia8 LHE to HepMC Converter with DPS" << std::endl;
    std::cout << "==================================================================" << std::endl;
    std::cout << "Configuration file: " << configFile << std::endl;
    std::cout << "Input LHE file    : " << inputLHE << std::endl;
    std::cout << "Output HepMC file : " << outputHepMC << std::endl;
    std::cout << "Random seed       : " << randomSeed << " (0 = time-based)" << std::endl;
    std::cout << "==================================================================" << std::endl;

    // Initialize Pythia
    Pythia pythia;
    
    // Read configuration file
    if (!pythia.readFile(configFile)) {
        std::cerr << "ERROR: Could not read configuration file: " << configFile << std::endl;
        return 1;
    }

    // Override LHE input file from command line
    pythia.readString("Beams:LHEF = " + inputLHE);

    // Set random seed if provided
    if (randomSeed != 0) {
        pythia.readString("Random:setSeed = on");
        pythia.readString("Random:seed = " + std::to_string(randomSeed));
        std::cout << "Random seed set to: " << randomSeed << std::endl;
    } else {
        std::cout << "Using time-based random seed" << std::endl;
    }

    // Initialize Pythia
    if (!pythia.init()) {
        std::cerr << "ERROR: Pythia initialization failed!" << std::endl;
        return 1;
    }

    // Create HepMC interface
    Pythia8::Pythia8ToHepMC toHepMC(outputHepMC);
    
    // Event loop
    int iEvent = 0;
    int iError = 0;
    int maxErrors = 10;
    
    std::cout << "\nStarting event processing..." << std::endl;
    
    while (true) {
        // Generate next event
        if (!pythia.next()) {
            // Check if we've reached the end of file
            if (pythia.info.atEndOfFile()) {
                std::cout << "\nReached end of LHE file." << std::endl;
                break;
            }
            
            // Handle errors
            iError++;
            std::cerr << "Warning: Event " << iEvent << " failed. Error count: " 
                     << iError << "/" << maxErrors << std::endl;
            
            if (iError >= maxErrors) {
                std::cerr << "ERROR: Too many errors (" << maxErrors 
                         << "), stopping event loop." << std::endl;
                break;
            }
            continue;
        }
        
        // Write event to HepMC
        toHepMC.writeNextEvent(pythia);
        
        iEvent++;
        
        // Print progress
        if (iEvent % 100 == 0) {
            std::cout << "Processed " << iEvent << " events..." << std::endl;
        }
    }
    
    // Finalize and print statistics
    std::cout << "\n==================================================================" << std::endl;
    std::cout << "Event processing completed" << std::endl;
    std::cout << "==================================================================" << std::endl;
    std::cout << "Total events processed: " << iEvent << std::endl;
    std::cout << "Total errors         : " << iError << std::endl;
    std::cout << "==================================================================" << std::endl;
    
    pythia.stat();
    
    std::cout << "\nHepMC output written to: " << outputHepMC << std::endl;
    std::cout << "==================================================================" << std::endl;

    return 0;
}
