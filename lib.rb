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
end
