#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
require 'open-uri'
require 'octokit'

ACCESS_TOKEN = ENV['GITHUB_TOKEN']
GITHUB_USER = ENV.fetch('GITHUB_USER')
REPO_PREFIX = 'lilypond-'
EXCLUDE = %w[lilypond-template lilypond-jekyll-template].freeze
FOLDERS = %w[a4 letter].freeze
BRANCH = 'gh-pages'
REPOSITORY_LIST_FILE = File.join('site', '_includes', 'repositories.markdown')

# Generates a SHA1 digest, in the same way as `git hash-object`.
#
# @param file_path [String] the path of the file to hash
# @return [String] the SHA1 digest
def github_sha1_hash_file(file_path)
  hash = Digest::SHA1.new

  # See https://chris.frederick.io/2013/05/27/calculating-git-sha-1-hashes-in-ruby.html
  hash.update("blob #{File.size(file_path)}\0")

  URI.open(file_path, 'r') do |io|
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

  URI.open(url) do |remote_file|
    File.open(file_path, 'wb') do |file|
      file.write(remote_file.read)
    end
  end
end

client = if ACCESS_TOKEN.nil? || ACCESS_TOKEN.empty?
           Octokit::Client.new
         else
           Octokit::Client.new(access_token: ACCESS_TOKEN)
         end
client.auto_paginate = true

# Empty the repository list
FileUtils.mkdir_p(File.dirname(REPOSITORY_LIST_FILE)) unless File.directory?(File.dirname(REPOSITORY_LIST_FILE))
File.write(REPOSITORY_LIST_FILE, '')

def partition_repo?(repo)
  repo.name.start_with?(REPO_PREFIX) &&
    repo.language == 'LilyPond' &&
    !EXCLUDE.include?(repo.name)
end

client.repositories(GITHUB_USER).select(&method(:partition_repo?)).each do |repo|
  File.write(REPOSITORY_LIST_FILE,
             "* [#{repo.description.delete_suffix('.')}](#{repo.homepage})\n",
             mode: 'a')

  FOLDERS.each do |folder|
    files = client.contents(repo.full_name, path: folder, query: { ref: BRANCH })
    next unless files

    dl_dir = File.join(GITHUB_USER, folder, repo.name)

    # Create the download directory
    FileUtils.mkdir_p(dl_dir) unless File.directory?(dl_dir)

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
