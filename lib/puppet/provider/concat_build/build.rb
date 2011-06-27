#
# Copyright (C) 2011 Onyx Point, Inc. <http://onyxpoint.com/>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
Puppet::Type.type(:concat_build ).provide :concat_build do
  require 'fileutils'

  desc "concat_build provider"

  def build_file
    if File.directory?("/var/lib/puppet/concat/fragments/#{@resource[:name]}") then
      begin
        FileUtils.mkdir_p("/var/lib/puppet/concat/output")

        f = File.open("/var/lib/puppet/concat/output/#{@resource[:name]}.out", "w+")
        input_lines = Array.new
        Dir.chdir("/var/lib/puppet/concat/fragments/#{@resource[:name]}") do
          Array(@resource[:order]).flatten.each do |pattern|
             Dir.glob(pattern).sort_by{ |k| human_sort(k) }.each do |file|

              prev_line = nil
              File.open(file).each do |line|

                if @resource.squeeze_blank? and line =~ /^\s*$/ then
                  if prev_line == :whitespace then
                    next
                  else
                     prev_line = :whitespace
                  end
                end

                out = clean_line(line)
                if not out.nil? then
		  # This is a bit hackish, but it would be nice to keep as much
		  # of the file out of memory as possible in the general case.
                  if @resource.sort? or not @resource[:unique].eql?(:false) then
                    input_lines.push(line)
                  else
		    f.puts(line)
                  end
                end

              end

              if not @resource.sort? and @resource[:unique].eql?(:false) then
                # Separate the files by the specified delimiter.
                f.seek(-1, IO::SEEK_END)
                if f.getc.chr.eql?("\n") then
                  f.seek(-1, IO::SEEK_END)
                  f.print(String(@resource[:file_delimiter]))
                end
              end
            end
          end
        end

        if not input_lines.empty? then
          if @resource.sort? then
            input_lines = input_lines.sort_by{ |k| human_sort(k) }
          end
          if not @resource[:unique].eql?(:false) then
            if @resource[:unique].eql?(:uniq) then
              require 'enumerator'
              input_lines = input_lines.enum_with_index.map { |x,i|
                if x.eql?(input_lines[i+1]) then
                  nil
                else
                  x
                end
              }.compact
            else
              input_lines = input_lines.uniq
            end
          end

          f.puts(input_lines.join(@resource[:file_delimiter]))
        else
          # Ensure that the end of the file is a '\n'
          f.seek(-(String(@resource[:file_delimiter]).length), IO::SEEK_END)
          curpos = f.pos
          if not f.getc.chr.eql?("\n") then
            f.seek(curpos)
            f.print("\n")
          end
          f.truncate(f.pos)
        end

        f.close

        FileUtils.touch("/var/lib/puppet/concat/fragments/#{@resource[:name]}/.~concat_fragments")
        if @resource[:target] and check_onlyif then
          debug "Copying /var/lib/puppet/concat/output/#{@resource[:name]}.out to #{@resource[:target]}"
          FileUtils.cp("/var/lib/puppet/concat/output/#{@resource[:name]}.out", @resource[:target])
        elsif @resource[:target] then
          debug "Not copying to #{@resource[:target]}, 'onlyif' check failed"
        elsif @resource[:onlyif] then
          debug "Specified 'onlyif' without 'target', ignoring."
        end
      rescue Exception => e
        fail Puppet::Error, e
      end
    elsif not @resource.quiet? then
      fail Puppet::Error, "The fragments directory at '/var/lib/puppet/concat/fragments/#{@resource[:name]}' does not exist!"
    end
  end

  private 

  # Return true if the command returns 0.
  def check_command(value)
    output, status = Puppet::Util::SUIDManager.run_and_capture([value])
    # The shell returns 127 if the command is missing.
    if status.exitstatus == 127
      raise ArgumentError, output
    end
 
    status.exitstatus == 0
  end

  def check_onlyif
    success = true

    if @resource[:onlyif] then
      cmds = [@resource[:onlyif]].flatten
      cmds.each do |cmd|
        return false unless check_command(cmd)
      end
    end

    success
  end

  def clean_line(line)
    newline = nil
    if Array(@resource[:clean_whitespace]).flatten.include?('leading') then
      line.sub!(/\s*$/, '')
    end
    if Array(@resource[:clean_whitespace]).flatten.include?('trailing') then
      line.sub!(/^\s*/, '')
    end
    if not (Array(@resource[:clean_whitespace]).flatten.include?('lines') and line =~ /^\s*$/) then
      newline = line
    end
    if @resource[:clean_comments] and line =~ /^#{@resource[:clean_comments]}/ then
      newline = nil
    end
    newline
  end

  def human_sort(obj)
    # This regex taken from http://www.bofh.org.uk/2007/12/16/comprehensible-sorting-in-ruby
    obj.to_s.split(/((?:(?:^|\s)[-+])?(?:\.\d+|\d+(?:\.\d+?(?:[eE]\d+)?(?:$|(?![eE\.])))?))/ms).map { |v| Float(v) rescue v.downcase}
  end

end
