# frozen_string_literal: true

module Partitions
  # GitHub username
  # @return [String]
  GITHUB_USER = ENV.fetch('GITHUB_USER')

  # List of instrument categories we want to create
  # @return [Array<String>]
  INSTRUMENTS = %w[
    piano
    bass-guitar
    guitar
    ukulele
    shamisen
    ocarina
  ].freeze

  # File format folders (`a4`, `letter`, `a3` or `tabloid`)
  # @return [Array<String>]
  FOLDERS = %w[a4 letter a3 tabloid].freeze

  # Branch on each repository where the built partitions are located
  # @return [String]
  BRANCH = 'gh-pages'
end
