#!/usr/bin/env ruby
require 'rubygems'
require 'bundler'
Bundler.require(:default, (ENV['RACK_ENV'] ||= :development.to_s).to_sym)

host, port = (ARGV[0] || '').split(':')
host ||= 'localhost'
port ||= 32400

def pretty_filesize n
  count = 0
  while  n >= 1024 and count < 4
    n /= 1024.0
    count += 1
  end
  format("%.2f",n) + %w(B KB MB GB TB)[count]
end

puts "Connecting to #{host}:#{port}"
server = Plex::Server.new(host, port)

server.library.sections.each do |section|
  case section.type
  when 'show' then
    videos = []
    section.all.each do |s|
      s.seasons.each do |m|
        m.episodes.each do |e|
          videos << e
        end
      end
    end
  when 'movie' then
    videos = section.all
  else
    next
  end

  print "Analyzing #{section.title.white}: 0/#{videos.length}"
  out = ''
  videos.each_with_index do |item, index|
    if not ['movie', 'episode'].include?(item.type)
      next
    end

    medias = item.medias
    if medias.length > 1
      out << "#{item.grandparent_title + ': ' if item.type == 'episode'}#{item.title}\n".white
      last_dir = nil
      medias.each do |m|
        m.parts.each do |part|
          dir = File.dirname(part.file)
          name = File.basename(part.file)
          size = pretty_filesize(part.size.to_i)
          unless last_dir.nil? or last_dir == dir
            out << "  #{dir.red}/#{name} (#{size})\n"
          else
            out << "  #{part.file} (#{size})\n"
          end
          last_dir = dir
        end
      end
    end
    print "\rAnalyzing #{section.title.white}: #{index+1}/#{videos.length}"
  end
  puts "\n\n#{out}\n"
end

