#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
require 'net/http'
require 'octokit'
require 'rss'
require_relative 'lib'

# GitHub access token (if nil, access the API anonymously)
# @return [String, nil]
ACCESS_TOKEN = ENV['GITHUB_TOKEN']
# Prefix of repositories containing LilyPond documents
# @return [String]
REPO_PREFIX = 'lilypond-'
# Repositories to ignore
# @return [Array<String>]
EXCLUDE = %w[lilypond-template lilypond-jekyll-template].freeze
# File format folders (`a4`, `letter`, `a3` or `tabloid`)
# @return [Array<String>]
FOLDERS = %w[a4 letter a3 tabloid].freeze
# Branch on each repository where the built partitions are located
# @return [String]
BRANCH = 'gh-pages'
# Folder container the repository list files
# @return [String]
REPOSITORY_LIST_FOLDER = File.join('site', '_includes')
# Jekyll Markdown file that should contain the list of repositories
# @return [String]
REPOSITORY_LIST_ALL_FILE = File.join(REPOSITORY_LIST_FOLDER, 'all_repositories.md')
# Default topics
# @return [Array<String>]
DEFAULT_TOPICS = %w[lilypond sheet-music].freeze

# Generates a SHA1 digest, in the same way as `git hash-object`.
#
# @param file_path [String] the path of the file to hash
# @return [String] the SHA1 digest
def github_sha1_hash_file(file_path)
  hash = Digest::SHA1.new

  # See https://chris.frederick.io/2013/05/27/calculating-git-sha-1-hashes-in-ruby.html
  hash.update("blob #{File.size(file_path)}\0")

  File.open(file_path, 'r') do |io|
    until io.eof?
      buffer = io.read(1024)
      hash.update(buffer)
    end
  end

  hash.hexdigest
end

# Downloads a file using HTTP GET.
#
# @param url [String] the file URL
# @param file_path [String] the path to download the file to
# @return [void]
def download_file(url, file_path)
  puts "Downloading #{url} to #{file_path}..."

  Net::HTTP.get_response(URI(url)) do |response|
    case response
    when Net::HTTPSuccess
      File.open(file_path, 'wb') do |file|
        file.write(response.body)
      end
    else
      raise "Received HTTP #{response.code} (#{response.message}) from #{url}"
    end
  end
end

# Generate a Markdown list of hashtags basic on a repository's topic list.
#
# @param topics [Array<String>] the topic list
# @return [String] the Markdown list
def generate_tag_list(topics)
  if topics.empty?
    ''
  else
    (topics.reject { DEFAULT_TOPICS.include?(_1) }.map do
       if Partitions::INSTRUMENTS.include?(_1)
         "[&#35;#{_1}]({% link #{_1}.md %})"
       else
         "&#35;#{_1}"
       end
     end.join(', ')).prepend('*').concat("*\n\n")
  end
end

# To prevent a warning when calling the Topics API
GITHUB_MEDIA_TYPE = 'application/vnd.github.mercy-preview+json'

client = if ACCESS_TOKEN.nil? || ACCESS_TOKEN.empty?
           Octokit::Client.new(accept: GITHUB_MEDIA_TYPE)
         else
           Octokit::Client.new(access_token: ACCESS_TOKEN, accept: GITHUB_MEDIA_TYPE)
         end
client.auto_paginate = true

# Empty the repository lists
FileUtils.mkdir_p(REPOSITORY_LIST_FOLDER) unless File.directory?(REPOSITORY_LIST_FOLDER)
File.write(REPOSITORY_LIST_ALL_FILE, '')
Partitions::INSTRUMENTS.each do |instrument|
  File.write(File.join(REPOSITORY_LIST_FOLDER, "#{instrument}.md"), '')
end

module Sawyer
  class Resource # rubocop:disable Style/Documentation
    def partition_repo?
      name.start_with?(REPO_PREFIX) &&
        language == 'LilyPond' &&
        !EXCLUDE.include?(name)
    end
  end
end

client.repositories(Partitions::GITHUB_USER).select(&:partition_repo?).each do |repo|
  topics_response = client.topics(repo.full_name)
  topics = if topics_response.key?(:names) && !topics_response[:names].empty?
             topics_response[:names]
           else
             []
           end
  topic_tag_list = generate_tag_list(topics)
  repo_description = "## [#{repo.name.delete_prefix(REPO_PREFIX)}](#{repo.homepage})\n\n"\
                     "#{repo.description}\n\n"\
                     "#{topic_tag_list}"

  # Update site/_includes/all_repositories.md
  File.write(REPOSITORY_LIST_ALL_FILE, repo_description, mode: 'a')

  topics.intersection(Partitions::INSTRUMENTS).each do |instrument|
    # Update site/_includes/#{instrument}.md
    File.write(File.join(REPOSITORY_LIST_FOLDER, "#{instrument}.md"), repo_description, mode: 'a')
  end

  FOLDERS.each do |folder|
    begin
      files = client.contents(repo.full_name, path: folder, query: { ref: BRANCH })
    rescue Octokit::NotFound
      # Folder doesn't exist in the repository, so skip
      next
    end

    next unless files

    dl_dir = File.join(Partitions::GITHUB_USER, folder, repo.name)

    # Create the download directory
    FileUtils.mkdir_p(dl_dir) unless File.directory?(dl_dir)

    # Save the repository's creation date and last push date
    File.write(File.join(dl_dir, 'created_at'), repo.created_at.iso8601)
    File.write(File.join(dl_dir, 'pushed_at'), repo.pushed_at.iso8601)

    files.each do |file|
      file_path = File.join(dl_dir, file.name)

      # Skip if it isn't a PDF file
      next if file.type != 'file' || File.extname(file.name) != '.pdf'

      # Skip the file if it's already downloaded
      next if File.exist?(file_path) && github_sha1_hash_file(file_path) == file.sha

      download_file(file.download_url, file_path)
    end
  end
end
