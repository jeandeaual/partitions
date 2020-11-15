#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pdf-reader'
require 'nokogiri'
require 'pdftoimage'
require 'rss'
require 'securerandom'
require 'set'

GITHUB_USER = ENV.fetch('GITHUB_USER')
FOLDERS = %w[a4 letter].freeze
BRANCH = 'gh-pages'
BASE_URL = '/partitions'
BASE_DIR = 'opds'
INSTRUMENTS = %w[
  piano
  harpsichord
  bass
  guitar
  ukulele
].freeze

module PDF
  KEYWORD_SEPARATORS = [';', ',', ' '].freeze

  class Reader # rubocop:disable Style/Documentation
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
    RELATED = 'related'
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

# BISAC (Book Industry Standards and Communications) Headings List
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

# LCSH (Library of Congress Subject Headings)
# https://www.dublincore.org/specifications/dublin-core/dcmi-terms/#http://purl.org/dc/terms/LCSH
module LCSH
  URI = 'http://purl.org/dc/terms/LCSH'

  module Term
    # https://id.loc.gov/authorities/subjects/sh2004002338.html
    SHEET_MUSIC = 'Sheet music'
  end
end

# Write the author to an OPDS feed.
#
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_author(xml)
  xml.name 'Alexis Jeandeau'
  xml.uri 'https://jeandeaual.github.io/partitions'
end

now = Time.now.iso8601

# Write the root OPDS feed.
#
# @param feed_path [String] the last part of the OPDS feed URI
# @param now [Time] the current time
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_root(feed_path, now, xml)
  xml.feed('xmlns' => RSS::Atom::URI,
           "xmlns:#{RSS::DC_PREFIX}" => RSS::DC_URI,
           "xmlns:#{OPDS::PREFIX}" => OPDS::URI) do
    href = [BASE_URL, BASE_DIR, feed_path].join('/')
    xml.id feed_path
    xml.updated now
    xml.link(rel: OPDS::Rel::SELF,
             href: href,
             type: OPDS::Link::NAVIGATION)
    xml.link(rel: OPDS::Rel::START,
             href: href,
             type: OPDS::Link::NAVIGATION)
    xml.title 'Partitions'
    xml.author do
      write_author xml
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

feed_path = 'root.xml'
root = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |xml| write_root(feed_path, now, xml) }

# Create the OPDS directory
opds_folder = File.join('site', BASE_DIR)
FileUtils.mkdir_p(opds_folder) unless File.directory?(opds_folder)

root_filepath = File.join(opds_folder, feed_path)
puts "Writing #{root_filepath}..."
File.write(root_filepath, root.to_xml)

# @!attribute id
#   @return [String] the unique ID of the OPDS entry
# @!attribute title
#   @return [String] document title (PDF Title metadata)
# @!attribute author
#   @return [String] document author (PDF Composer or Author metadata)
# @!attribute subject
#   @return [String] document subject (PDF Subject metadata)
# @!attribute basename
#   @return [String] base name of the PDF file (with no extension)
# @!attribute repository
#   @return [String] GitHub repository the PDF file belongs to
# @!attribute cover_href
#   @return [String] local hyperlink of the cover image
# @!attribute cover_path
#   @return [String] local file path of the cover image
# @!attribute thumbnail_href
#   @return [String] local hyperlink of the thumbnail
# @!attribute thumbnail_path
#   @return [String] local file path of the thumbnail
# @!attribute keywords
#   @return [Array<String>] list of keywords (PDF Keywords metadata, split)
Document = Struct.new(
  :id,
  :title,
  :author,
  :subject,
  :basename,
  :repository,
  :cover_href,
  :cover_path,
  :thumbnail_href,
  :thumbnail_path,
  :keywords
)

# Write the categories in an OPDS feed.
#
# @param keywords [Array<String>] the PDF keywords
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_categories(keywords, xml)
  # BISAC
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

  # LCSH
  xml.category(scheme: LCSH::URI, term: LCSH::Term::SHEET_MUSIC)
end

# Generate a cover file.
#
# @param image [PDFToImage::Image] the path of the PDF file to parse
# @param basename [String] the basename of the PDF file, with no extension
# @param repository [String] the name of the GitHub repository the file belongs to
# @param cover_folder [String] the path of the folder containing the cover files
# @return [Array<(String, String)>] the href and path of the generated file
def generate_cover(image, basename, repository, cover_folder)
  cover_name = "#{basename}.jpg"
  cover_href = [BASE_URL, 'covers', repository, cover_name].join('/')
  cover_path = File.join(cover_folder, cover_name)

  unless File.file?(cover_path)
    puts "Writing #{cover_path}..."
    image.resize('50%').save(cover_path)
  end

  [cover_href, cover_path]
end

# Generate a thumbnail.
#
# @param image [PDFToImage::Image] the path of the PDF file to parse
# @param basename [String] the basename of the PDF file, with no extension
# @param repository [String] the name of the GitHub repository the file belongs to
# @param cover_folder [String] the path of the folder containing the cover files
# @return [Array<(String, String)>] the href and path of the generated file
def generate_thumbnail(image, basename, repository, cover_folder)
  thumbnail_name = "#{basename}_thumbnail.jpg"
  thumbnail_href = [BASE_URL, 'covers', repository, thumbnail_name].join('/')
  thumbnail_path = File.join(cover_folder, thumbnail_name)

  unless File.file?(thumbnail_path)
    puts "Writing #{thumbnail_path}..."
    image.resize('150').quality('80%').save(thumbnail_path)
  end

  [thumbnail_href, thumbnail_path]
end

# Parse the author of a PDF document.
#
# @param reader [PDF::Reader] the PDF file reader
# @param doc [Document] the document
# @return [void]
def parse_author(reader, doc)
  %i[Composer Author].each do |key|
    next unless reader.info[key]

    doc.author = reader.info[key].tr(' ', ' ')
    break
  end
end

# Parse a PDF document.
#
# @param folder [String] either `a4` or `letter`
# @param pdf_file [String] the path of the PDF file to parse
# @return [Document] the parsed document
def parse_entry(folder, pdf_file)
  doc = Document.new
  reader = PDF::Reader.new(pdf_file)

  doc.basename = File.basename(pdf_file, '.pdf')
  doc.repository = File.dirname(pdf_file).delete_prefix(File.join(GITHUB_USER, folder, ''))

  # Generate the cover and thumbnail
  images = PDFToImage.open(pdf_file)
  cover = images[0]
  thumbnail = cover.clone

  cover_folder = File.join('site', 'covers', doc.repository)
  FileUtils.mkdir_p(cover_folder) unless File.directory?(cover_folder)

  doc.cover_href, doc.cover_path = generate_cover(cover, doc.basename, doc.repository, cover_folder)
  doc.thumbnail_href, doc.thumbnail_path = generate_thumbnail(thumbnail, doc.basename, doc.repository, cover_folder)

  doc.title = reader.info[:Title]
  doc.id = [doc.repository, folder, doc.basename].join('/')

  doc.subject = reader.info[:Subject]

  parse_author(reader, doc)

  doc.keywords = reader.keywords

  doc
end

# Parse a PDF document.
#
# @param format [String] either `a4` or `letter`
# @param doc [Document] the PDF document
# @param now [Time] the current time
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_entry(format, doc, now, xml)
  xml.entry do
    xml.title doc.title
    xml.id doc.id
    xml[RSS::DC_PREFIX].issued now
    xml.updated now

    write_categories(doc.keywords, xml)

    xml.author do
      xml.name doc.author
    end

    xml.content(doc.subject, type: 'text')

    xml.link(rel: OPDS::Rel::IMAGE,
             href: doc.cover_href,
             type: 'image/jpeg')
    xml.link(rel: OPDS::Rel::THUMBNAIL,
             href: doc.thumbnail_href,
             type: 'image/jpeg')
    xml.link(rel: OPDS::Rel::RELATED,
             href: "https://#{GITHUB_USER}.github.io/#{doc.repository}",
             type: 'text/html',
             title: 'Website')
    xml.link(rel: OPDS::Rel::OPEN_ACCESS,
             href: [
               'https://raw.githubusercontent.com',
               GITHUB_USER,
               doc.repository,
               BRANCH,
               format,
               "#{doc.basename}.pdf"
             ].join('/'),
             type: 'application/pdf',
             title: "#{format.capitalize} PDF")
  end
end

# Write the OPDS feeds containing all entries for a specific page format.
#
# @param format [String] either `a4` or `letter`
# @param feed_path [String] the last part of the OPDS feed URI
# @param now [Time] the current time
# @param docs [Array<Document>] the PDF documents
# @param instruments [Set<String>] the instruments
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_format_subsections(format, feed_path, now, instruments, xml)
  xml.feed('xmlns' => RSS::Atom::URI,
           "xmlns:#{RSS::DC_PREFIX}" => RSS::DC_URI,
           "xmlns:#{OPDS::PREFIX}" => OPDS::URI) do
    href = [BASE_URL, BASE_DIR, feed_path].join('/')
    start = [BASE_URL, BASE_DIR, 'root.xml'].join('/')
    xml.id href
    xml.link(rel: OPDS::Rel::SELF,
             href: href,
             type: OPDS::Link::NAVIGATION)
    xml.link(rel: OPDS::Rel::START,
             href: start,
             type: OPDS::Link::NAVIGATION)
    xml.link(rel: OPDS::Rel::UP,
             href: start,
             type: OPDS::Link::NAVIGATION)
    xml.title "#{format.capitalize} Partitions"
    xml.author do
      write_author xml
    end

    # All
    xml.entry do
      href = [BASE_URL, BASE_DIR, format, 'all.xml'].join('/')
      xml.id href
      xml.title 'All'
      xml.link(rel: OPDS::Rel::SUBSECTION,
               href: href,
               type: OPDS::Link::ACQUISITION)
      xml.updated now
      xml.content('All', type: 'text')
    end

    instruments.each do |instrument|
      xml.entry do
        href = [BASE_URL, BASE_DIR, format, "#{instrument}.xml"].join('/')
        xml.id href
        xml.title instrument.capitalize
        xml.link(rel: OPDS::Rel::SUBSECTION,
                 href: href,
                 type: OPDS::Link::ACQUISITION)
        xml.updated now
        xml.content(instrument.capitalize, type: 'text')
      end
    end
  end
end

# Write the OPDS feeds containing all entries for a specific page format.
#
# @param format [String] either `a4` or `letter`
# @param feed_path [String] the last part of the OPDS feed URI
# @param now [Time] the current time
# @param docs [Array<Document>] the PDF documents
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_all_entries(format, feed_path, now, docs, xml)
  xml.feed('xmlns' => RSS::Atom::URI,
           "xmlns:#{RSS::DC_PREFIX}" => RSS::DC_URI,
           "xmlns:#{OPDS::PREFIX}" => OPDS::URI) do
    href = [BASE_URL, BASE_DIR, feed_path].join('/')
    xml.id href
    xml.link(rel: OPDS::Rel::SELF,
             href: href,
             type: OPDS::Link::ACQUISITION)
    xml.link(rel: OPDS::Rel::START,
             href: [BASE_URL, BASE_DIR, 'root.xml'].join('/'),
             type: OPDS::Link::ACQUISITION)
    xml.link(rel: OPDS::Rel::UP,
             href: [BASE_URL, BASE_DIR, "#{format}.xml"].join('/'),
             type: OPDS::Link::ACQUISITION)
    xml.title "All #{format.capitalize} Partitions"
    xml.author do
      write_author xml
    end
    xml.updated now

    docs.sort_by { |doc| [doc.author || '', doc.title] }.each do |doc|
      write_entry(format, doc, now, xml)
    end
  end
end

# Write the OPDS feeds containing all entries for a specific instrument.
#
# @param format [String] either `a4` or `letter`
# @param instrument [String] the instrument
# @param now [Time] the current time
# @param docs [Array<Document>] the PDF documents
# @param xml [Nokogiri::XML::Builder] the XML builder
# @return [void]
def write_instrument_entries(format, instrument, now, docs, xml)
  xml.feed('xmlns' => RSS::Atom::URI,
           "xmlns:#{RSS::DC_PREFIX}" => RSS::DC_URI,
           "xmlns:#{OPDS::PREFIX}" => OPDS::URI) do
    href = [BASE_URL, BASE_DIR, format, "#{instrument}.xml"].join('/')
    xml.id href
    xml.link(rel: OPDS::Rel::SELF,
             href: href,
             type: OPDS::Link::ACQUISITION)
    xml.link(rel: OPDS::Rel::START,
             href: [BASE_URL, BASE_DIR, 'root.xml'].join('/'),
             type: OPDS::Link::ACQUISITION)
    xml.link(rel: OPDS::Rel::UP,
             href: [BASE_URL, BASE_DIR, "#{format}.xml"].join('/'),
             type: OPDS::Link::ACQUISITION)
    xml.title "#{instrument.capitalize} Partitions"
    xml.author do
      write_author xml
    end
    xml.updated now

    docs.sort_by { |doc| [doc.author || '', doc.title] }.each do |doc|
      write_entry(format, doc, now, xml)
    end
  end
end

FOLDERS.each do |folder|
  feed_path = "#{folder}.xml"

  docs = []

  # Parse the PDF files
  Dir["#{GITHUB_USER}/#{folder}/**/*.pdf"].each do |pdf_file|
    docs.push(parse_entry(folder, pdf_file))
  end

  found_instruments = Set[]

  docs.each do |doc|
    found_instruments.merge(doc.keywords.intersection(INSTRUMENTS))
  end

  # Print the navigation
  format_categories = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
    write_format_subsections(folder, feed_path, now, found_instruments, xml)
  end

  filepath = File.join(opds_folder, feed_path)
  puts "Writing #{filepath}..."
  File.write(filepath, format_categories.to_xml)

  folder_path = File.join(opds_folder, folder)
  FileUtils.mkdir_p(folder_path) unless File.directory?(folder_path)

  # Print the feeds with all entries
  feed_path = [folder, 'all.xml'].join('/')

  format_all = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
    write_all_entries(folder, feed_path, now, docs, xml)
  end

  filepath = File.join(folder_path, 'all.xml')
  puts "Writing #{filepath}..."
  File.write(filepath, format_all.to_xml)

  # Print the feeds per instruments
  found_instruments.each do |instrument|
    format_instrument = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      write_instrument_entries(folder, instrument, now, docs.select { |doc| doc.keywords.include?(instrument) }, xml)
    end

    filepath = File.join(folder_path, "#{instrument}.xml")
    puts "Writing #{filepath}..."
    File.write(filepath, format_instrument.to_xml)
  end
end