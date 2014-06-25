require 'linguist/file_blob'
require 'linguist/lazy_blob'
require 'rugged'

module Linguist
  # A Repository is an abstraction of a Grit::Repo or a basic file
  # system tree. It holds a list of paths pointing to Blobish objects.
  #
  # Its primary purpose is for gathering language statistics across
  # the entire project.
  class Repository
    attr_reader :repository

    # Public: Initialize a new Repository
    #
    # Returns a Repository
    def initialize(repo, commit_oid, existing_stats = nil)
      @repository = repo
      @commit_oid = commit_oid
      @old_commit_oid, @old_stats = existing_stats if existing_stats
    end

    # Public: Returns a breakdown of language stats.
    #
    # Examples
    #
    #   # => { Language['Ruby'] => 46319,
    #          Language['JavaScript'] => 258 }
    #
    # Returns a Hash of Language keys and Integer size values.
    def languages
      @sizes ||= begin
        sizes = Hash.new { 0 }
        cache.each do |_, (language, size)|
          sizes[language] += size
        end
        sizes
      end
    end

    # Public: Get primary Language of repository.
    #
    # Returns a Language
    def language
      @language ||= begin
        primary = languages.max_by { |(_, size)| size }
        primary && primary[0]
      end
    end

    # Public: Get the total size of the repository.
    #
    # Returns a byte size Integer
    def size
      @size ||= languages.inject(0) { |s,(_,v)| s + v }
    end

    # Public: Return the language breakdown of this repository by file
    def breakdown_by_file
      @file_breakdown ||= begin
        breakdown = Hash.new { |h,k| h[k] = Array.new }
        cache.each do |filename, (language, _)|
          breakdown[language] << filename
        end
        breakdown
      end
    end

    def compute_stats(old_commit_oid, commit_oid, cache = nil)
      file_map = cache ? cache.dup : {}
      old_tree = old_commit_oid && Rugged::Commit.lookup(repository, old_commit_oid).tree
      new_tree = Rugged::Commit.lookup(repository, commit_oid).tree

      diff = Rugged::Tree.diff(repository, old_tree, new_tree)

      diff.each_delta do |delta|
        old = delta.old_file[:path]
        new = delta.new_file[:path]

        file_map.delete(old)
        next if delta.binary

        if [:added, :modified].include? delta.status
          mode = delta.new_file[:mode].to_s(8)
          blob = Linguist::LazyBlob.new(repository, delta.new_file[:oid], new, mode)

          # Skip vendored or generated blobs
          next if blob.vendored? || blob.generated? || blob.language.nil?

          # Only include programming languages and acceptable markup languages
          if blob.language.type == :programming || Language.detectable_markup.include?(blob.language.name)
            file_map[new] = [blob.language.group.name, blob.size]
          end
        end
      end

      file_map
    end

    def cache
      @cache ||= begin
        if @old_commit_oid == @commit_oid
          @old_stats
        else
          compute_stats(@old_commit_oid, @commit_oid, @old_stats)
        end
      end
    end
  end
end
