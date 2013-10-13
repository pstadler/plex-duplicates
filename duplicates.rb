#!/usr/bin/env ruby
require 'rubygems'
require 'bundler'
Bundler.require(:default, (ENV['RACK_ENV'] ||= :development.to_s).to_sym)

host, port = (ARGV[0] || '').split(':')
host ||= 'localhost'
port ||= 32400

module Plex
  class Video
    def initialize(node)
      @attribute_hash = {}
      node.attributes.each do |method, val|
        @attribute_hash[Plex.underscore(method)] = val.value
        define_singleton_method(Plex.underscore(method).to_sym) do
          val.value
        end
      end
      # monkey patch @media to support multiple entries
      @media      = node.search('Media').map    { |m| Plex::Media.new(m)    }
      @genres     = node.search('Genre').map    { |m| Plex::Genre.new(m)    }
      @writers    = node.search('Writer').map   { |m| Plex::Writer.new(m)   }
      @directors  = node.search('Director').map { |m| Plex::Director.new(m) }
      @roles      = node.search('Role').map     { |m| Plex::Role.new(m)     }
    end
  end
end

puts "Connecting to #{host}:#{port}"
server = Plex::Server.new(host, port)

server.library.sections.each do |section|
  if section.type == 'show'
    videos = []
    section.all.each do |s|
      s.seasons.each do |m|
        m.episodes.each do |e|
          #puts "#{e.grandparent_title} - #{e.title}"
          videos << e
        end
      end
    end
  else
    videos = section.all
  end

  print "Analyzing #{section.title.white}: 0/#{videos.length}"
  out = ''
  videos.each_with_index do |item, index|
    if not ['movie', 'episode'].include?(item.type)
      next
    end

    media = item.media
    if media.length > 1
      out << "#{item.grandparent_title + ': ' if item.type == 'episode'}#{item.title}\n".white
      last_dir = nil
      media.each do |m|
        m.parts.each do |part|
          dir = File.dirname(part.file)
          name = File.basename(part.file)
          unless last_dir.nil? or last_dir == dir
            out << "  #{dir.red}/#{name}\n"
          else
            out << "  #{part.file}\n"
          end
          last_dir = dir
        end
      end
    end
    print "\rAnalyzing #{section.title.white}: #{index+1}/#{videos.length}"
  end
  puts "\n\n#{out}\n"
end

