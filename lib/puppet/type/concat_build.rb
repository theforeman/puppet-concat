#
# Copyright (C) 2011 Onyx Point, Inc. <http://onyxpoint.com/>
#
# This file is part of the Onyx Point concat puppet module.
#
# The Onyx Point concat puppet module is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
Puppet::Type.newtype(:concat_build) do
  require 'puppet/util/diff'
  @doc = "Build file from fragments"

  def extractexe(cmd)
    # easy case: command was quoted
    if cmd =~ /^"([^"]+)"/
      $1
    else
      cmd.split(/ /)[0]
    end
  end

  def validatecmd(cmd)
    exe = extractexe(cmd)
    fail Puppet::Error, "'#{cmd}' is unqualifed" if File.expand_path(exe) != exe
  end

  newparam(:clean_comments) do
    desc "If a line begins with the specified string it will not be printed in the output file."
  end

  newparam(:clean_whitespace) do
    desc "Cleans whitespace.  Can be passed an array.  'lines' will cause the 
          output to not contain any blank lines. 'all' is equivalent to 
          [leading, trailing, lines]"
    munge do |value|
      [value].flatten!
      if value.include?('all') then
        return ['leading', 'trailing', 'lines']
      end
      [value].flatten.uniq
    end

    validate do |value|
      [value].flatten!
      if value.include?('none') and value.uniq.length > 1 then
        fail Puppet::Error, "You cannot specify 'none' with any other options"
      end
    end

    newvalues(:leading, :trailing, :lines, :all, :none)
    defaultto [:none]
  end

  newparam(:file_delimiter) do
    desc "Acts as the delimiter between concatenated file fragments. For
	  instance, if you have two files with contents 'foo' and 'bar', the
	  result with a file_delimiter of ':' will be a file containing
          'foo:bar'."
    defaultto "\n"
  end

  newparam(:name) do
    isnamevar
    validate do |value|
      fail Puppet::Error, "concat_name cannot include '../'!" if value =~ /\.\.\//
    end
  end

  newparam(:onlyif) do
    desc "Copy file to target only if this command exits with status '0'"
    validate do |cmds|
      [cmds].flatten! 

      cmds.each do |cmd|
        @resource.validatecmd(cmd)
      end
    end

    munge do |cmds|
      [cmds].flatten
    end
  end

  newparam(:sort, :boolean => true) do
    desc "Sort the built file. This tries to sort in a human fashion with 
	  1 < 2 < 10 < 20 < a, etc..  sort. Note that this will need to read
          the entire file into memory

          Example Sort:

          ['a','1','b','10','2','20','Z','A']

          translates to

          ['1','2','10','20','a','A','b','Z']

          Note: If you use a file delimiter with this, it *will not* be sorted!"
    newvalues(:true, :false)
    defaultto :false
  end

  newparam(:squeeze_blank, :boolean => true) do
    desc "Never output more than one blank line"
    newvalues(:true, :false)
    defaultto :false
  end

  newparam(:target) do
    desc "Fully qualified path to copy output file to"
    validate do |path|
      unless path =~ /^\/$/ or path =~ /^\/[^\/]/
        fail Puppet::Error, "File paths must be fully qualified, not '#{path}'"
      end
    end
  end

  newparam(:parent_build) do
    desc "Specify the parent to this build step. Only needed for multiple
          staged builds. Can be an array."
  end

  newparam(:quiet, :boolean => true) do
    desc "Suppress errors when no fragments exist for build"
    newvalues(:true, :false)
    defaultto :false
  end

  newparam(:unique) do
    desc "Only print unique lines to the output file. Sort takes precedence.
          This does not affect file delimiters.

	  true: Uses Ruby's Array.uniq function. It will remove all duplicates
          regardless  of where they are in the file.
 
	  uniq: Acts like the uniq command found in GNU coreutils and only
          removes consecutive duplicates."

    newvalues(:true, :false, :uniq)
    defaultto :false
  end

  newproperty(:order, :array_matching => :all) do
    include Puppet::Util::Diff

    desc "Array containing ordering info for build"

    defaultto ["*"]

    def retrieve
      return resource[:order].join(',')
    end

    def insync?(is)
      # Always build the file for diff'ing - otherwise you can hit a file-not-found later
      provider.build_file(false)
      
      # Can't possibly be insync if the target file doesn't even exist
      return false unless File.exists?(@resource[:target])

      # Build the temporary file, and then diff it against the actual one
      diffs = diff(@resource[:target],"/var/lib/puppet/concat/output/#{@resource[:name]}.out")
      puts diffs unless (result = diffs.empty?)
      result
    end

    def sync
      # Move the tempfile into place
      provider.build_file(true)
    end

    def change_to_s(currentvalue, newvalue)
      "#{[newvalue].flatten.join(',')} used for ordering"
    end
  end

  autorequire(:concat_build) do
    req = []
    # resource contains all concat_build resources from the catalog that are
    # children of this concat_build
    resource = catalog.resources.find_all { |r| r.is_a?(Puppet::Type.type(:concat_build)) and r[:parent_build] and Array(r[:parent_build]).flatten.include?(self[:name]) }
    if not resource.empty? then
      req << resource
    end
    req.flatten!
    req.each { |r| debug "Autorequiring #{r}" }
    req
  end

  autorequire(:concat_fragment) do
    req = []
    # resource contains all concat_fragment resources from the catalog that
    # belog to this concat_build
    resource = catalog.resources.find_all { |r| r.is_a?(Puppet::Type.type(:concat_fragment)) and r[:name] =~ /^#{self[:name]}\+.+/ }
    if not resource.empty? then
      req << resource
    elsif not self.quiet? then
      err "No fragments specified for group #{self[:name]}!"
    end
    # clean up the fragments directory for this build if there are no fragments
    # in the catalog
    if resource.empty? and File.directory?("/var/lib/puppet/concat/fragments/#{self[:name]}") then
      FileUtils.rm_rf("/var/lib/puppet/concat/fragments/#{self[:name]}")
    else
      # Cleanup any cruft fragments from previous runs which are no longer needed
      files = resource.map { |r| "/var/lib/puppet/concat/fragments/#{self[:name]}/#{r[:name].split("+")[1]}" }
      (Dir.glob("/var/lib/puppet/concat/fragments/#{self[:name]}/*") - files).each { |f| File.delete(f) }
    end
    if self[:parent_build] then
      found_parent = false
      Array(self[:parent_build]).flatten.each do |parent_build|
        # Checks to see if there is a concat_build for each parent_build specified
        if not catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:concat_build)) and r[:name].eql?(parent_build)}.nil? then
          found_parent = true
        elsif not self.quiet? then
          warning "No concat_build found for parent_build #{parent_build}"
        end
        # frags contains all concat_fragment resources for the parent concat_build
        frags = catalog.resources.find_all { |r| r.is_a?(Puppet::Type.type(:concat_fragment)) and r[:name] =~ /^#{parent_build}\+.+/ }
        if not frags.empty? then
          req << frags
        end
      end
      if not found_parent then
        err "No concat_build found for any of #{Array(self[:parent_build]).flatten.join(",")}"
      end
    end
    req.flatten!
    req.each { |r| debug "Autorequiring #{r}" }
    req
  end

end
