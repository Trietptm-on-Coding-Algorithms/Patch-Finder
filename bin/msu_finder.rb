#!/usr/bin/env ruby

##
#
# This tool allows you to collect Microsoft patches.
# Once you have downloaded all the .msu patches, you can use tools/extract_msu.bat to
# automatically extract them.
#
##

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'core/helper'
require 'core/config'
require 'optparse'
require 'msu'

class PatchFinderBin

  include PatchFinder::Helper

  attr_reader :args

  def banner
    @banner ||= lambda {
      doc_path = File.join(PatchFinder::Config.doc_directory, 'msu_finder.txt')
      read_file(doc_path)
    }.call
  end

  def get_parsed_options
    options = {}

    parser = OptionParser.new do |opt|
      opt.banner = banner
      opt.separator ''
      opt.separator 'Specific options:'

      opt.on('-q', '--query <keyword>', 'Find advisories including this keyword') do |v|
        options[:keyword] = v
      end

      opt.on('-s', '--search-engine <engine>', '(Optional) The type of search engine to use (Technet or Google). Default: Technet') do |v|
        case v.to_s
        when /^google$/i
          options[:search_engine] = :google
        when /^technet$/i
          options[:search_engine] = :technet
        else
          fail OptionParser::InvalidOption, "Invalid search engine: #{v}"
        end
      end

      opt.on('-r', '--regex <string>', '(Optional) Specify what type of links you want') do |v|
        options[:regex] = v
      end

      opt.on('--apikey <key>', '(Optional) Google API key.') do |v|
        options[:google_api_key] = v
      end

      opt.on('--cx <id>', '(Optional) Google search engine ID.') do |v|
        options[:google_search_engine_id] = v
      end

      opt.on('-d', '--dir <string>', '(Optional) The directory to save the patches') do |v|
        unless File.directory?(v)
          fail OptionParser::InvalidOption, "Directory not found: #{v}"
        end

        options[:destdir] = v
      end

      opt.on_tail('-h', '--help', 'Show this message') do
        $stderr.puts opt
        exit
      end
    end

    parser.parse!

    if options.empty?
      fail OptionParser::MissingArgument, 'No options set, try -h for usage'
    elsif options[:keyword].nil? || options[:keyword].empty?
      fail OptionParser::MissingArgument, '-q is required'
    end

    unless options[:search_engine]
      options[:search_engine] = :technet
    end

    if options[:search_engine] == :google
      if options[:google_api_key].nil? || options[:google_search_engine_id].empty?
        fail OptionParser::MissingArgument, 'No API key set for Google'
      elsif options[:google_search_engine_id].nil? || options[:google_search_engine_id].empty?
        fail OptionParser::MissingArgument, 'No search engine ID set for Google'
      end
    end

    options
  end

  def initialize
    @args = get_parsed_options
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
    print_error(e.message)
    exit
  end

  def main
    cli = PatchFinder::MSU.new
    links = cli.find_msu_download_links(args)
    if args[:destdir]
      print_status("Download links found: #{links.length}")
      print_status('Downloading files, please wait...')
      download_files(links, args[:destdir])
    else
      print_status('Download links found:')
      print_line(links * "\n")
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  bin = PatchFinderBin.new
  bin.main
end