#include "HepMC/GenEvent.h"
#include "HepMC/IO_GenEvent.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

int main(int argc, char *argv[]) {
  // Check command line arguments
  if (argc < 3) {
    std::cerr << "Usage: " << argv[0]
              << " output. hepmc input1.hepmc [input2.hepmc ... ]\n";
    std::cerr
        << "Concatenates multiple HepMC2 files into a single output file.\n";
    std::cerr << "Event numbers will be renumbered sequentially.\n";
    return 1;
  }

  std::string output_file = argv[1];
  std::vector<std::string> input_files;

  for (int i = 2; i < argc; ++i) {
    input_files.push_back(argv[i]);
  }

  std::cout << "Output file: " << output_file << std::endl;
  std::cout << "Input files (" << input_files.size() << "):" << std::endl;
  for (const auto &fname : input_files) {
    std::cout << "  - " << fname << std::endl;
  }

  // Open output stream
  HepMC::IO_GenEvent output_stream(output_file, std::ios::out);

  int total_events = 0;
  int event_number = 1;

  // Process each input file
  for (const auto &fname : input_files) {
    std::cout << "\nProcessing:  " << fname << std::endl;

    HepMC::IO_GenEvent input_stream(fname, std::ios::in);

    if (input_stream.rdstate() == std::ios::failbit) {
      std::cerr << "ERROR: Failed to open input file: " << fname << std::endl;
      return 1;
    }

    int file_events = 0;
    HepMC::GenEvent *evt = nullptr;

    while ((evt = input_stream.read_next_event())) {
      // Renumber events sequentially
      evt->set_event_number(event_number);

      // Write to output
      output_stream.write_event(evt);

      // Clean up
      delete evt;

      file_events++;
      event_number++;
      total_events++;

      // Progress indicator for large files
      if (file_events % 1000 == 0) {
        std::cout << "  Processed " << file_events << " events..." << std::endl;
      }
    }

    std::cout << "  Complete: " << file_events << " events from this file"
              << std::endl;
  }

  std::cout << "\n=================================\n";
  std::cout << "Concatenation complete!\n";
  std::cout << "Total events written: " << total_events << std::endl;
  std::cout << "Output file: " << output_file << std::endl;
  std::cout << "=================================\n";

  return 0;
}