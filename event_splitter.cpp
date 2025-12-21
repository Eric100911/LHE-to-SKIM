#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <iomanip> // For std::setw, std::setfill
#include <iostream>
#include <memory>  // For std::unique_ptr
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

// --- Argument Parsing ---
std::string get_cmd_option(char **begin, char **end,
                           const std::string &option) {
  char **itr = std::find_if(
      begin, end, [&](const char *arg) { return std::string(arg) == option; });
  if (itr != end && ++itr != end) {
    return *itr;
  }
  return "";
}

bool cmd_option_exists(char **begin, char **end, const std::string &option) {
  return std::find_if(begin, end, [&](const char *arg) {
           return std::string(arg) == option;
         }) != end;
}

// --- Main Logic ---
int main(int argc, char *argv[]) {
  // --- CRITICAL PERFORMANCE TWEAK ---
  std::ios_base::sync_with_stdio(false);

  // --- Parse Command Line Arguments ---
  if (cmd_option_exists(argv, argv + argc, "-h") ||
      cmd_option_exists(argv, argv + argc, "--help")) {
    std::cout << "Usage: ./event_splitter [options]\n\n"
              << "Options:\n"
              << "  -i, --input <file>        Required. Source LHE file.\n"
              << "  -o, --output-dir <dir>    Required. Output directory.\n"
              << "  -n, --num-files <int>     Required. Number of files to "
                 "split into.\n"
              << "  --file-prefix <prefix>    Optional. Prefix for output "
                 "files (default: 'event_file_').\n"
              << "  --file-offset <int>       Optional.  Starting number for "
                 "output files (default: 0).\n"
              << "  --subdirs                 Optional. Create subdirectories "
                 "(e. g., <dir>/000/file_00001.lhe).\n"
              << "  -seq, --sequential        Optional. Fill files in "
                 "round-robin sequence instead of random.\n";
    return 0;
  }

  std::string source_file = get_cmd_option(argv, argv + argc, "-i");
  if (source_file.empty())
    source_file = get_cmd_option(argv, argv + argc, "--input");

  std::string output_dir = get_cmd_option(argv, argv + argc, "-o");
  if (output_dir.empty())
    output_dir = get_cmd_option(argv, argv + argc, "--output-dir");

  std::string num_files_str = get_cmd_option(argv, argv + argc, "-n");
  if (num_files_str.empty())
    num_files_str = get_cmd_option(argv, argv + argc, "--num-files");

  if (source_file.empty() || output_dir.empty() || num_files_str.empty()) {
    std::cerr << "Fatal: Missing required arguments!  Use --help for usage."
              << std::endl;
    return 1;
  }

  int num_files = std::stoi(num_files_str);
  std::string file_prefix = get_cmd_option(argv, argv + argc, "--file-prefix");
  if (file_prefix.empty())
    file_prefix = "event_file_";

  std::string file_offset_str =
      get_cmd_option(argv, argv + argc, "--file-offset");
  int file_offset = file_offset_str.empty() ? 0 : std::stoi(file_offset_str);

  bool use_subdirs = cmd_option_exists(argv, argv + argc, "--subdirs");

  // --- NEW: Check for sequential mode ---
  bool sequential_mode = cmd_option_exists(argv, argv + argc, "--sequential") ||
                         cmd_option_exists(argv, argv + argc, "-seq");

  // --- Setup output directory ---
  std::string mkdir_cmd = "mkdir -p " + output_dir;
  if (system(mkdir_cmd.c_str()) != 0) {
    std::cerr << "Fatal: Could not create output directory '" << output_dir
              << "'" << std::endl;
    return 1;
  }

  // --- Setup Random Generator (Only used if NOT sequential) ---
  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<> dist(0, num_files - 1);

  // --- Open all output files ---
  std::cout << "Opening " << num_files << " output files..." << std::endl;
  std::vector<std::unique_ptr<std::ofstream>> out_files;
  out_files.reserve(num_files);  // Now this is safe! 

  for (int i = 0; i < num_files; ++i) {
    int file_num = file_offset + i;
    std::stringstream ss;
    ss << output_dir << "/";
    if (use_subdirs) {
      ss << std::setw(3) << std::setfill('0') << (file_num / 100) << "/";
      std::string cmd = "mkdir -p " + ss.str();
      system(cmd.c_str());
    }
    ss << file_prefix << std::setw(5) << std::setfill('0') << file_num
       << ".lhe";

    out_files.emplace_back(new std::ofstream(ss.str()));
    if (!out_files.back()->is_open()) {
      std::cerr << "Fatal: Could not open " << ss.str() << std::endl;
      return 1;
    }
  }

  // --- Open source file ---
  std::ifstream in_file(source_file);
  if (!in_file.is_open()) {
    std::cerr << "Fatal: Could not open source file " << source_file
              << std::endl;
    return 1;
  }

  // --- State Machine & Buffers ---
  enum State { HEADER, IN_EVENT };
  State current_state = HEADER;
  std::stringstream header_buf, event_buf;
  std::string line, footer_line;
  long long event_count = 0;

  std::cout << "Reading source file and processing events..." << std::endl;
  if (sequential_mode) {
    std::cout << "Mode: SEQUENTIAL (Round-Robin)" << std::endl;
  } else {
    std::cout << "Mode: RANDOM ASSIGNMENT" << std::endl;
  }

  while (std::getline(in_file, line)) {
    line += '\n';

    if (current_state == HEADER) {
      if (line.find("<event>") != std::string::npos) {
        // Header finished (includes the first <event> tag)
        std::cout << "Header found.  Writing to all files..." << std::endl;
        std::string header_str = header_buf.str();
        for (auto &f : out_files) {
          *f << header_str;
        }

        // Start tracking the first event
        event_buf.str("");
        event_buf.clear();
        event_buf << line;
        current_state = IN_EVENT;
      } else {
        header_buf << line;
      }
    } else if (current_state == IN_EVENT) {
      event_buf << line;
      if (line.find("</event>") != std::string::npos) {
        // Determine target file index
        int target_idx;
        if (sequential_mode) {
          // Round-robin: 0, 1, 2, ...  N, 0, 1... 
          target_idx = event_count % num_files;
        } else {
          // Random assignment
          target_idx = dist(gen);
        }

        *out_files[target_idx] << event_buf.rdbuf();

        event_buf.str("");
        event_buf.clear();
        event_count++;

        if (event_count % 50000 == 0) {
          std::cout << "Processed " << event_count << " events..." << std::endl;
        }
      }
    }

    if (line.find("</LesHouchesEvents>") != std::string::npos) {
      footer_line = line;
      break;
    }
  }

  // --- Write footer and close all files ---
  std::cout << "Processed " << event_count
            << " events. Writing footers and closing files..." << std::endl;
  for (auto &f : out_files) {
    *f << footer_line;
    f->close();
  }

  in_file.close();
  std::cout << "Done." << std::endl;
  return 0;
} 
