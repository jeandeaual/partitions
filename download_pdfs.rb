#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
require 'net/http'
require 'octokit'

ACCESS_TOKEN = ENV['GITHUB_TOKEN']
GITHUB_USER = ENV.fetch('GITHUB_USER')
REPO_PREFIX = 'lilypond-'
EXCLUDE = %w[lilypond-template lilypond-jekyll-template].freeze
FOLDERS = %w[a4 letter].freeze
BRANCH = 'gh-pages'
REPOSITORY_LIST_FILE = File.join('site', '_includes', 'repositories.markdown')
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

# To prevent a warning when calling the Topics API
GITHUB_MEDIA_TYPE = 'application/vnd.github.mercy-preview+json'

client = if ACCESS_TOKEN.nil? || ACCESS_TOKEN.empty?
           Octokit::Client.new(accept: GITHUB_MEDIA_TYPE)
         else
           Octokit::Client.new(access_token: ACCESS_TOKEN, accept: GITHUB_MEDIA_TYPE)
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
  topics = client.topics(repo.full_name)

  topic_list = if topics.key?(:names) && !topics[:names].empty?
                 (topics[:names].reject { DEFAULT_TOPICS.include?(_1) }.map { "&#35;#{_1}" }.join(', '))
                   .prepend('*')
                   .concat("*\n\n")
               else
                 ''
               end

  # Update site/_includes/repositories.markdown
  File.write(REPOSITORY_LIST_FILE,
             "## [#{repo.name.delete_prefix(REPO_PREFIX)}](#{repo.homepage})\n\n#{repo.description}\n\n#{topic_list}",
             mode: 'a')

  FOLDERS.each do |folder|
    files = client.contents(repo.full_name, path: folder, query: { ref: BRANCH })
    next unless files

    dl_dir = File.join(GITHUB_USER, folder, repo.name)

    # Save the repository's creation date and last push date
    File.write(File.join(dl_dir, 'created_at'), repo.created_at.strftime('%FT%TZ'))
    File.write(File.join(dl_dir, 'pushed_at'), repo.pushed_at.strftime('%FT%TZ'))

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
