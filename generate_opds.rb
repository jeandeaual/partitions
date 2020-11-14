#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pdf-reader'
require 'nokogiri'
require 'rss'
require 'securerandom'

GITHUB_USER = ENV.fetch('GITHUB_USER')
FOLDERS = %w[a4 letter].freeze
BRANCH = 'gh-pages'
BASE_URL = '/partitions'
BASE_DIR = 'opds'

module PDF
  KEYWORD_SEPARATORS = [';', ',', ' '].freeze

  class Reader
    # Converts the document's keyword string into an array.
    # Tries, in turn, `;`, `,` and ` ` as separators.
    #
    # @return [Array<String>] the keyword array
    def keywords
      keyword_string = info[:Keywords]

      KEYWORD_SEPARATORS.each do |sep|
        return keyword_string.split(',').map(&:strip) if keyword_string.include?(sep)
      end

      return [keyword_string] unless keyword_string.empty?

      []
    end
  end
end

module OPDS
  BASE_URI = 'http://opds-spec.org'
  private_constant :BASE_URI

  PREFIX = 'opds'
  URI = "#{BASE_URI}/2010/catalog"

  module Rel
    SELF = 'self'
    START = 'start'
    UP = 'up'
    SUBSECTION = 'subsection'
    CRAWLABLE = "#{BASE_URI}/crawlable"
    ACQUISITION = "#{BASE_URI}/acquisition"
    OPEN_ACCESS = "#{ACQUISITION}/open-access"
    IMAGE = "#{BASE_URI}/image"
    THUMBNAIL = "#{IMAGE}/thumbnail"
  end

  module Link
    BASE_PROFILE = 'application/atom+xml;profile=opds-catalog;kind='
    private_constant :BASE_PROFILE

    ACQUISITION = "#{BASE_PROFILE}acquisition"
    NAVIGATION = "#{BASE_PROFILE}navigation"
  end
end

module BISAC
  URI = 'http://www.bisg.org/standards/bisac_subject/index.html'

  module Term
    PRINTED_MUSIC_GENERAL = 'MUS037000'
    PRINTED_MUSIC_BAND = 'MUS037020'
    PRINTED_MUSIC_FRETTED = 'MUS037040'
    PRINTED_MUSIC_PERCUSSION = 'MUS037080'
    PRINTED_MUSIC_PIANO = 'MUS037090'
  end

  module Label
    PRINTED_MUSIC_GENERAL = 'MUSIC / Printed Music / General'
    PRINTED_MUSIC_BAND = 'MUSIC / Printed Music / Band & Orchestra'
    PRINTED_MUSIC_FRETTED = 'MUSIC / Printed Music / Guitar & Fretted Instruments'
    PRINTED_MUSIC_PERCUSSION = 'MUSIC / Printed Music / Percussion'
    PRINTED_MUSIC_PIANO = 'MUSIC / Printed Music / Piano & Keyboard Repertoire'
  end
end

now = Time.now.iso8601

feed_path = 'root.xml'
root = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
  xml.feed('xmlns' => RSS::Atom::URI,
           "xmlns:#{RSS::DC_PREFIX}" => RSS::DC_URI,
           "xmlns:#{OPDS::PREFIX}" => OPDS::URI) do
    href = [BASE_URL, BASE_DIR, feed_path].join('/')
    xml.id feed_path
    xml.updated now
    xml.link(rel: OPDS::Rel::SELF,
             href: href,
             type: OPDS::Link::ACQUISITION)
    xml.link(rel: OPDS::Rel::START,
             href: href,
             type: OPDS::Link::ACQUISITION)
    xml.title 'Partitions'
    xml.author do
      xml.name 'Alexis Jeandeau'
      xml.uri 'https://jeandeaual.github.io/partitions'
    end
    FOLDERS.each do |folder|
      xml.entry do
        href = [BASE_URL, BASE_DIR, "#{folder}.xml"].join('/')
        xml.id href
        xml.title folder.capitalize
        xml.link(rel: OPDS::Rel::SUBSECTION,
                 href: href,
                 type: OPDS::Link::NAVIGATION)
        xml.updated now
        xml.content("Partitions in #{folder.capitalize} format", type: 'text')
      end
    end
  end
end

# Create the OPDS directory
opds_folder = File.join('site', BASE_DIR)
FileUtils.mkdir_p(opds_folder) unless File.directory?(opds_folder)

root_filepath = File.join(opds_folder, feed_path)
puts "Writing #{root_filepath}..."
File.write(root_filepath, root.to_xml)

FOLDERS.each do |folder|
  feed_path = "#{folder}.xml"
  format_root = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
    xml.feed('xmlns' => RSS::Atom::URI,
             "xmlns:#{RSS::DC_PREFIX}" => RSS::DC_URI,
             "xmlns:#{OPDS::PREFIX}" => OPDS::URI) do
      href = [BASE_URL, BASE_DIR, feed_path].join('/')
      xml.id href
      xml.link(rel: OPDS::Rel::SELF,
               href: href,
               type: OPDS::Link::ACQUISITION)
      xml.link(rel: OPDS::Rel::START,
               href: href,
               type: OPDS::Link::ACQUISITION)
      xml.link(rel: OPDS::Rel::UP,
               href: [BASE_URL, BASE_DIR, 'root.xml'].join('/'),
               type: OPDS::Link::ACQUISITION)
      xml.title "#{folder.capitalize} Partitions"
      xml.author do
        xml.name 'Alexis Jeandeau'
        xml.uri 'https://jeandeaual.github.io/partitions'
      end
      xml.updated now

      Dir["#{GITHUB_USER}/#{folder}/**/*.pdf"].each do |file|
        reader = PDF::Reader.new(file)
        basename = File.basename(file)
        repository = File.dirname(file).delete_prefix(File.join(GITHUB_USER, folder, ''))
        keywords = reader.keywords

        xml.entry do
          xml.title reader.info[:Title]
          xml.id [repository, folder, basename].join('/')
          xml[RSS::DC_PREFIX].issued now
          xml.updated now
          xml.author do
            xml.name reader.info[:Composer].gsub(' ', ' ')
          end
          xml[RSS::DC_PREFIX].language 'en'
          if keywords.include?('piano')
            xml.category(scheme: BISAC::URI,
                         term: BISAC::Term::PRINTED_MUSIC_PIANO,
                         label: BISAC::Label::PRINTED_MUSIC_PIANO)
          elsif keywords.include?('guitar') || keywords.include?('bass')
            xml.category(scheme: BISAC::URI,
                         term: BISAC::Term::PRINTED_MUSIC_FRETTED,
                         label: BISAC::Label::PRINTED_MUSIC_FRETTED)
          else
            xml.category(scheme: BISAC::URI,
                         term: BISAC::Term::PRINTED_MUSIC_GENERAL,
                         label: BISAC::Label::PRINTED_MUSIC_GENERAL)
          end
          xml.content(reader.info[:Subject], type: 'text')
          xml.link(rel: OPDS::Rel::OPEN_ACCESS,
                   href: "https://raw.githubusercontent.com/jeandeaual/#{repository}/#{BRANCH}/#{folder}/#{basename}",
                   type: 'application/pdf',
                   title: "#{folder.capitalize} PDF")
        end
      end
    end
  end

  filepath = File.join(opds_folder, "#{folder}.xml")
  puts "Writing #{filepath}..."
  File.write(filepath, format_root.to_xml)
end
